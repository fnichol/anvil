#!/usr/bin/env python3
"""Removes the files and directories matching globs (task: clean:*).

The globs are the task's `paths` usage argument; each `clean:*` template
supplies its own as the argument's default, so every language or behavior says
what it generates, and the `clean` role removes it all. Globs are relative to
the project root and may use `**` and a simple `{a,b}` alternation. Absolute
paths, paths that leave the project, `.git` and the project root itself are
refused.
"""

import argparse
import glob
import os
import re
import shutil
import sys
from pathlib import Path

import mise_task

ROOT = Path.cwd().resolve()
BRACES = re.compile(r"\{([^{}]*)\}")


def expand_braces(pattern: str) -> list[str]:
    """Expands `{a,b}` alternations (not nested) into separate globs."""
    match = BRACES.search(pattern)
    if match is None:
        return [pattern]
    head, tail = pattern[:match.start()], pattern[match.end():]
    return [
        expanded for option in match.group(1).split(",")
        for expanded in expand_braces(head + option + tail)
    ]


def check_safe(pattern: str) -> None:
    if os.path.isabs(pattern) or ".." in Path(pattern).parts:
        raise mise_task.TaskError(
            f"refusing {pattern!r}: paths must be relative to the project")


def matches(pattern: str) -> list[Path]:
    """Existing paths for one glob (symlinks included, never followed).

    Like a shell, `*` and `**` skip hidden entries; a pattern component that
    starts with a dot (`.cache`, `.*.o`) matches them.
    """
    found = []
    for hit in sorted(glob.glob(pattern, recursive=True)):
        path = Path(os.path.abspath(hit))  # not resolve(): keep symlinks
        relative = path.relative_to(ROOT)  # safe: patterns are relative
        if relative == Path(".") or relative.parts[0] == ".git":
            raise mise_task.TaskError(f"refusing to remove {hit!r}")
        found.append(path)
    return found


def remove(path: Path) -> None:
    try:
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink()
    except OSError as err:
        raise mise_task.TaskError(
            f"cannot remove {path.relative_to(ROOT).as_posix()}: "
            f"{err.strerror or err} (is it outside the task's `allow_write`?)"
        ) from err


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    usage = mise_task.Usage()
    dry_run = mise_task.dry_run()
    verbose = mise_task.verbosity() >= 1

    patterns = usage.args("paths")
    if not patterns:
        raise mise_task.TaskError("no paths to clean")
    for pattern in patterns:
        check_safe(pattern)

    # Validate every match before removing anything, so a refused path never
    # leaves a partial clean behind.
    plan: list[tuple[str, Path]] = []
    for pattern in patterns:
        found = [p for glob_ in expand_braces(pattern) for p in matches(glob_)]
        if not found and verbose:
            print(f"no match: {pattern}", file=sys.stderr)
        plan.extend((pattern, path) for path in found)

    for _, path in plan:
        # A parent removed earlier in this run takes its children with it.
        if not os.path.lexists(path):
            continue
        shown = path.relative_to(ROOT).as_posix()
        if dry_run:
            print(f"would remove {shown}")
            continue
        remove(path)
        print(f"removed {shown}")
    return 0


if __name__ == "__main__":
    mise_task.run_main(main)
