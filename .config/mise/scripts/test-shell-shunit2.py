#!/usr/bin/env python3
"""Runs the shell tests with shUnit2 (task: test:shell, via shunit2).

Receives shell source files: the sources changed since the last successful run,
or the files named on the command line (the task's `files` usage argument).
Test files (`*_test.sh`) run individually. If any other source is present, the
code under test may have changed, so every test runs.
"""

import argparse
import sys
from pathlib import Path

import mise_task

TEST_SUFFIX = "_test.sh"
TESTS_DIR = Path("tests")

# Output that means a test is broken even if shUnit2 reports it as passing,
# such as a helper that was never loaded or a missing command. These errors
# are easy to miss because they do not fail the assertions.
FAIL_ON_OUTPUT = ("command not found", )


def tests_to_run(files: list[str]) -> list[str]:
    if all(f.endswith(TEST_SUFFIX) for f in files):
        return files
    return sorted(p.as_posix() for p in TESTS_DIR.rglob("*" + TEST_SUFFIX))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mise_task.add_sources_arguments(parser)
    args = parser.parse_args()

    files = mise_task.partition_files(args, mise_task.Usage())
    if not files.sources:
        print("test-shell-shunit2: no files to test", file=sys.stderr)
        return 0

    failed = False
    for test in tests_to_run(files.sources):
        print(f"\n--- {test}", flush=True)
        status, hits = mise_task.run_tool_watching([f"./{test}"],
                                                   FAIL_ON_OUTPUT,
                                                   echo_at=2)
        if status != 0:
            failed = True
        if hits:
            failed = True
            print(f"\ntest-shell-shunit2: error: {test} printed "
                  f"{' or '.join(map(repr, FAIL_ON_OUTPUT))}, which is "
                  "treated as a failure even though the tests passed:",
                  file=sys.stderr)
            for line in hits:
                print(f"  {line}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    mise_task.run_main(main)
