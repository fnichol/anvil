#!/usr/bin/env python3
"""Lints shell sources with Shuck (task: check:lint:shell).

Lints only the sources that changed since the last successful run, unless
Shuck's own configuration changed, in which case every source is linted.
Files named on the command line (the task's `files` usage argument) override
this selection.
"""

import argparse
import sys

import mise_task

# Tool configuration tracked as task sources. A change invalidates every
# result, but the file itself is not a shell source to lint.
CATEGORIES = {"configs": ("shuck.toml",)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mise_task.add_sources_arguments(parser)
    args = parser.parse_args()

    files = mise_task.partition_files(args, mise_task.Usage(), CATEGORIES)
    if not files.sources:
        print("check-lint-shell: no files to check", file=sys.stderr)
        return 0
    return mise_task.run_tool(["shuck", "check", *files.sources])


if __name__ == "__main__":
    mise_task.run_main(main)
