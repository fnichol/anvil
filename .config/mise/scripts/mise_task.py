"""Shared helpers for Mise tasks implemented as Python programs.

Python 3.12+, standard library only.

A task's `run` line is expected to be a constant shape that only hands over
what Mise alone can compute, as JSON arrays on the command line:

    python3 <task>.py --all-json '[...]' --changed-json '[...]'

`--changed all` replaces `--changed-json` when both lists would not fit in the
kernel's limit on a single argument (128 KiB on Linux, and the whole rendered
`run` is one), and `--sources-too-long` replaces both when even the full list
does not fit. See the `check:lint:shell` template for the guards.

Everything else comes from the `usage_*` environment variables, set by Mise
from the task's `usage` spec (see `Usage`).
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import shlex
import subprocess
import sys
import threading
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path


class TaskError(Exception):
    """A failure that should be reported to the user without a traceback."""


def run_main(main: Callable[[], int]) -> None:
    """Runs a task's `main`, turning `TaskError` into a clean exit status 2."""
    try:
        code = main()
    except TaskError as err:
        print(f"{os.path.basename(sys.argv[0])}: error: {err}",
              file=sys.stderr)
        code = 2
    except KeyboardInterrupt:
        code = 130
    sys.exit(code)


class Usage:
    """Read access to the `usage_*` environment variables set by Mise.

    Names follow Mise: dashes become underscores, so `--no-sudo` is read with
    `usage.flag("no-sudo")`. Unset flags are absent from the environment.
    """

    def __init__(self, environ: Mapping[str, str] | None = None) -> None:
        self._env = os.environ if environ is None else environ

    @staticmethod
    def _key(name: str) -> str:
        return "usage_" + name.replace("-", "_")

    def value(self, name: str, default: str | None = None) -> str | None:
        """A single-valued flag or argument, or `default` when unset."""
        return self._env.get(self._key(name), default)

    def flag(self, name: str) -> bool:
        """A boolean flag; true only when Mise set it to `true`."""
        return self.value(name) == "true"

    def count(self, name: str) -> int:
        """A counted flag such as `-vvv`; 0 when unset."""
        raw = self.value(name)
        if raw is None or raw == "":
            return 0
        try:
            return int(raw)
        except ValueError as err:
            raise TaskError(f"flag {name!r} is not a count: {raw!r}") from err

    def values(self, name: str) -> list[str]:
        """A repeatable flag or variadic argument (Mise shell-quotes them)."""
        raw = self.value(name)
        if not raw:
            return []
        try:
            return shlex.split(raw)
        except ValueError as err:
            raise TaskError(f"cannot split {name!r}: {raw!r} ({err})") from err

    def args(self, name: str = "files") -> list[str]:
        """The variadic positional argument, `files` unless named otherwise."""
        return self.values(name)


SOURCES = "sources"
"""The category of every file that no other category claims."""

Categories = Mapping[str, Sequence[str]]
"""Category name -> paths or `fnmatch` globs, e.g. `{"configs": ["x.toml"]}`."""


@dataclass
class Partition:
    """Files split into categories; every file lands in exactly one.

    `sources` is the default category (all files no other category claims) and
    `configs` is the conventional one for tool configuration. Other categories
    are read with `part["name"]`; an unknown or empty category is `[]`.
    """

    kinds: dict[str, list[str]]

    def __getitem__(self, kind: str) -> list[str]:
        return self.kinds.get(kind, [])

    @property
    def sources(self) -> list[str]:
        return self[SOURCES]

    @property
    def configs(self) -> list[str]:
        return self["configs"]


def partition_by(files: Sequence[str], categories: Categories) -> Partition:
    """Splits `files` by `categories`; the first matching category wins."""
    kinds: dict[str, list[str]] = {SOURCES: []}
    for path in files:
        for kind, patterns in categories.items():
            if any(fnmatch.fnmatchcase(path, pat) for pat in patterns):
                kinds.setdefault(kind, []).append(path)
                break
        else:
            kinds[SOURCES].append(path)
    return Partition(kinds)


@dataclass
class Sources:
    """The sources of a task: every one, and those changed since the last run."""

    all: list[str] | None
    """Every source, or `None` when there were too many to pass."""

    changed: list[str] | None
    """Changed sources, or `None` meaning "everything may have changed"."""

    def partition(
        self,
        categories: Categories | None = None,
        invalidated_by: Sequence[str] = ("configs", )
    ) -> Partition:
        """The files to process this run, partitioned by `categories`.

        The `sources` part is what to process: just the changed sources, or
        the full list when nothing is known to be unchanged or when a file in
        one of the `invalidated_by` categories (tool configuration that
        affects every source) changed. The other categories always list every
        matching file, changed or not, so a tool can reference them.
        """
        if self.all is None:
            raise TaskError("too many sources to pass on the command line; "
                            "name files explicitly (`-- <files>`)")
        categories = categories or {}
        full = partition_by(self.all, categories)
        if self.changed is None:
            chosen = self.all
        else:
            hit = partition_by(self.changed, categories)
            invalidated = any(hit[kind] for kind in invalidated_by)
            chosen = self.all if invalidated else self.changed
        parts = partition_by(chosen, categories).kinds
        parts.update({k: v for k, v in full.kinds.items() if k != SOURCES})
        return Partition(parts)


DUMP_SOURCES_AT = 3
"""The verbosity at which the sources handed over by `run` are printed."""


def dump_sources_arguments(args: argparse.Namespace) -> None:
    """Prints the source arguments from the `run` line, for debugging.

    Every path of a JSON list gets its own `--option: path` line (so it can be
    searched and grepped), and an empty list is shown as `(empty)`.
    """
    for option, raw in (("--all-json", args.all_json),
                        ("--changed-json", args.changed_json)):
        if raw is None:
            continue
        try:
            paths = _json_list(raw, option)
        except TaskError:
            print(f"{option}: {raw}", file=sys.stderr)  # invalid, as given
            continue
        for path in paths or ["(empty)"]:
            print(f"{option}: {path}", file=sys.stderr)
    if args.changed is not None:
        print(f"--changed: {args.changed}", file=sys.stderr)
    if args.sources_too_long:
        print("--sources-too-long", file=sys.stderr)


def partition_files(args: argparse.Namespace,
                    usage: Usage,
                    categories: Categories | None = None) -> Partition:
    """The files a task should process, partitioned by `categories`.

    Files named on the command line (the task's `files` usage argument) win;
    otherwise the sources handed over by the `run` line (see `Sources`).
    """
    if verbosity() >= DUMP_SOURCES_AT:
        dump_sources_arguments(args)
    explicit = usage.args("files")
    if explicit:
        return partition_by(explicit, categories or {})
    return sources_from_args(args).partition(categories)


def verbosity() -> int:
    """How many times `-v`/`--verbose` was given (the task's `verbose` flag)."""
    return Usage().count("verbose")


def dry_run() -> bool:
    """Whether the task's `-n`/`--dry-run` flag was given."""
    return Usage().flag("dry-run")


def sync_file(source: Path, target: Path, label: str) -> None:
    """Copies `source` to `target` unless it is already identical.

    Reports what happened, and under `--dry-run` only what would happen.
    """
    data = source.read_bytes()
    if target.is_file() and target.read_bytes() == data:
        print(f"{target}: {label} already vendored")
        return
    if dry_run():
        verb = "update" if target.exists() else "create"
        print(f"{target}: would {verb} with {label}")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    print(f"{target}: vendored {label}")


def run_tool(command: Sequence[str], echo_at: int = 1) -> int:
    """Runs `command` and returns its exit status.

    The command is first echoed to stderr when `verbosity()` is at least
    `echo_at` (so the default echoes at `-v`).
    """
    if verbosity() >= echo_at:
        print("+ " + shlex.join(command), file=sys.stderr)
    try:
        return subprocess.run(list(command), check=False).returncode
    except FileNotFoundError as err:
        raise TaskError(f"cannot run {command[0]}: {err}") from err


def run_tool_watching(command: Sequence[str],
                      watch: Sequence[str],
                      echo_at: int = 1) -> tuple[int, list[str]]:
    """Like `run_tool`, also collecting output lines that contain `watch`.

    The command's output is passed through live, stdout to stdout and stderr to
    stderr. Returns its exit status and every line (from either stream) that
    contains one of the `watch` strings, so a caller can fail on output that
    signals trouble even when the command itself exits successfully.
    """
    if verbosity() >= echo_at:
        print("+ " + shlex.join(command), file=sys.stderr)
    try:
        proc = subprocess.Popen(list(command),
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                text=True,
                                errors="replace")
    except FileNotFoundError as err:
        raise TaskError(f"cannot run {command[0]}: {err}") from err

    hits: list[str] = []

    def forward(source, sink) -> None:
        for line in source:
            sink.write(line)
            sink.flush()
            if any(needle in line for needle in watch):
                hits.append(line.rstrip("\n"))

    threads = [
        threading.Thread(target=forward, args=(proc.stdout, sys.stdout)),
        threading.Thread(target=forward, args=(proc.stderr, sys.stderr)),
    ]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    return proc.wait(), hits


def add_sources_arguments(parser: argparse.ArgumentParser) -> None:
    """Adds the arguments a task's `run` line uses to hand over its sources."""
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--all-json",
                       metavar="JSON",
                       help="JSON array of every source")
    group.add_argument("--sources-too-long",
                       action="store_true",
                       help="there were too many sources to pass")
    changed = parser.add_mutually_exclusive_group()
    changed.add_argument(
        "--changed-json",
        metavar="JSON",
        help="JSON array of sources changed since the last successful run",
    )
    changed.add_argument(
        "--changed",
        choices=["all"],
        help="treat every source as changed (e.g. too many to list twice)",
    )


def sources_from_args(args: argparse.Namespace) -> Sources:
    """Builds `Sources` from arguments added by `add_sources_arguments`."""
    all_sources = (None if args.sources_too_long else _json_list(
        args.all_json, "--all-json"))
    changed = (_json_list(args.changed_json, "--changed-json")
               if args.changed_json is not None else None)
    return Sources(all=all_sources, changed=changed)


def _json_list(raw: str, option: str) -> list[str]:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as err:
        raise TaskError(f"{option} is not valid JSON: {err}") from err
    if not isinstance(data, list) or not all(isinstance(x, str) for x in data):
        raise TaskError(f"{option} must be a JSON array of strings")
    return data
