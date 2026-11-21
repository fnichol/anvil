#!/usr/bin/env python3
"""Creates directories before a sandboxed task needs them (task: setup:*).

A task's sandbox can only write to paths that already exist when it starts, so
a prerequisite task creates them first. The directories are the task's `paths`
usage argument; each `setup:*` template supplies its own as the argument's
default. Existing directories are left alone.
"""

import argparse
import sys
from pathlib import Path

import mise_task


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    usage = mise_task.Usage()

    paths = usage.args("paths")
    if not paths:
        raise mise_task.TaskError("no directories to create")

    for raw in paths:
        path = Path(raw).expanduser()
        if path.is_dir():
            if mise_task.verbosity() >= 1:
                print(f"exists {path}", file=sys.stderr)
            continue
        if mise_task.dry_run():
            print(f"would create {path}")
            continue
        try:
            path.mkdir(parents=True, exist_ok=True)
        except OSError as err:
            raise mise_task.TaskError(
                f"cannot create {path}: {err.strerror or err}") from err
        print(f"created {path}")
    return 0


if __name__ == "__main__":
    mise_task.run_main(main)
