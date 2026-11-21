#!/usr/bin/env python3
"""Checks the formatting of shell sources with shfmt (task: check:format:shell).

Checks only the sources that changed since the last successful run. Files named
on the command line (the task's `files` usage argument) override this
selection.
"""

import argparse
import sys

import mise_task

SHFMT_OPTIONS = (
    "--indent", "2",
    "--case-indent",
    "--binary-next-line",
    "--diff",
    "--list",
)  # fmt: skip


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mise_task.add_sources_arguments(parser)
    args = parser.parse_args()

    files = mise_task.partition_files(args, mise_task.Usage())
    if not files.sources:
        print("check-format-shell: no files to check", file=sys.stderr)
        return 0
    return mise_task.run_tool(["shfmt", *SHFMT_OPTIONS, *files.sources])


if __name__ == "__main__":
    mise_task.run_main(main)
