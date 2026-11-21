#!/usr/bin/env python3
"""Checks that JSON sources are well formed with jq (task: check:format:json).

Checks only the sources that changed since the last successful run. Files named
on the command line (the task's `files` usage argument) override this
selection. Every file is checked, and the exit status is non-zero if any of
them is invalid.
"""

import argparse
import sys

import mise_task


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mise_task.add_sources_arguments(parser)
    args = parser.parse_args()

    files = mise_task.partition_files(args, mise_task.Usage())
    if not files.sources:
        print("check-format-json: no files to check", file=sys.stderr)
        return 0

    failed = False
    for path in files.sources:
        if mise_task.run_tool(["jq", "empty", path]) != 0:
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    mise_task.run_main(main)
