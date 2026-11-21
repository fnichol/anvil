#!/usr/bin/env python3
"""Checks that pinned tool versions are the latest available (task: check-tool-versions).

Every `tool_version_<name>` var in `conf.d/*.toml` is compared against
`mise latest <tool>`. The tool is found by looking for the template (or task)
`tools` entry whose version uses that var, so the full Mise tool identifier
(`cargo:shuck-cli`, `github:fnichol/libsh`, ...) is never repeated anywhere.
Tools from the `http:` backend have no way to list versions and are reported
as unchecked. A pin with fewer than three parts (`3.12`) is a series that
floats with patch releases: it is checked against the latest version in that
series, and the newest overall is shown for information only. Exits non-zero if
any pin is out of date or cannot be resolved.
"""

import argparse
import re
import subprocess
import sys
import tomllib
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import mise_task

MISE_DIR = Path(__file__).resolve().parent.parent
CONFIG_FILES = (*sorted((MISE_DIR / "conf.d").glob("*.toml")),
                MISE_DIR.parent / "mise.toml")
VAR_PREFIX = "tool_version_"
VAR_REFERENCE = re.compile(r"\bvars\.(" + VAR_PREFIX + r"\w+)")
UNCHECKABLE_BACKENDS = ("http:",)


def load(path: Path) -> dict:
    try:
        with path.open("rb") as handle:
            return tomllib.load(handle)
    except FileNotFoundError:
        return {}
    except tomllib.TOMLDecodeError as err:
        raise mise_task.TaskError(f"cannot parse {path}: {err}") from err


def pinned_versions(configs: list[dict]) -> dict[str, str]:
    """`tool_version_*` vars: name (without prefix) -> pinned version."""
    pins: dict[str, str] = {}
    for config in configs:
        for var, value in config.get("vars", {}).items():
            if var.startswith(VAR_PREFIX) and isinstance(value, str):
                pins[var.removeprefix(VAR_PREFIX)] = value
    return pins


def tool_ids(configs: list[dict]) -> dict[str, set[str]]:
    """Var name (without prefix) -> Mise tool ids whose version uses that var."""
    found: dict[str, set[str]] = {}
    for config in configs:
        tables = [*config.get("task_templates", {}).values(),
                  *config.get("tasks", {}).values()]
        for table in tables:
            for tool, spec in table.get("tools", {}).items():
                version = spec.get("version", "") if isinstance(spec, dict) else spec
                for var in VAR_REFERENCE.findall(str(version)):
                    found.setdefault(var.removeprefix(VAR_PREFIX),
                                     set()).add(tool)
    return found


def is_series(pin: str) -> bool:
    """Whether `pin` names a release series (`3.12`) and not one version."""
    return len(pin.split(".")) < 3


def latest(tool: str, series: str | None = None) -> str | None:
    """The latest version `mise latest` reports for `tool` (in `series`)."""
    spec = f"{tool}@{series}" if series else tool
    proc = subprocess.run(["mise", "latest", spec],
                          capture_output=True,
                          text=True,
                          check=False)
    out = proc.stdout.strip()
    return out if proc.returncode == 0 and out else None


def check(name: str, pinned: str, tools: set[str]) -> tuple[str, bool]:
    """One report line and whether it counts as a failure."""
    if not tools:
        return (f"{name}: {pinned} (unchecked: no tool uses "
                f"{VAR_PREFIX}{name})", False)
    if len(tools) > 1:
        return f"{name}: used by several tools: {', '.join(sorted(tools))}", True
    (tool,) = tools
    if tool.startswith(UNCHECKABLE_BACKENDS):
        return f"{name}: {pinned} (unchecked: {tool} cannot list versions)", False
    if is_series(pinned):
        in_series, newest = latest(tool, pinned), latest(tool)
        if in_series is None:
            return f"{name}: no versions of {tool} in series {pinned}", True
        extra = f"; newest overall {newest}" if newest else ""
        return (f"{name}: {pinned} (series, up to date: latest is "
                f"{in_series}{extra})", False)
    newest = latest(tool)
    if newest is None:
        return f"{name}: could not determine latest version of {tool}", True
    if newest == pinned:
        return f"{name}: {pinned} (up to date)", False
    return f"{name}: {pinned} -> {newest} (OUTDATED)", True


def main() -> int:
    argparse.ArgumentParser(description=__doc__).parse_args()

    configs = [load(path) for path in CONFIG_FILES]
    pins = pinned_versions(configs)
    ids = tool_ids(configs)
    if not pins:
        raise mise_task.TaskError(f"no {VAR_PREFIX}* vars found in "
                                  f"{MISE_DIR / 'conf.d'}")

    names = sorted(pins)
    if mise_task.verbosity() >= 1:
        for name in names:
            print(f"+ {name}: {sorted(ids.get(name, ()))}", file=sys.stderr)
    with ThreadPoolExecutor() as pool:
        results = list(pool.map(lambda n: check(n, pins[n], ids.get(n, set())),
                                names))
    for line, _ in results:
        print(line)
    return 1 if any(failed for _, failed in results) else 0


if __name__ == "__main__":
    mise_task.run_main(main)
