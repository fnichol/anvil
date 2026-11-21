#!/usr/bin/env python3
"""Vendors shUnit2 into vendor/lib/ (task: vendor:shunit2).

The release is the one pinned by `tool_version_shunit2` in
`conf.d/vars-tool-version.toml`: Mise installs it as a tool, and this copies
its `shunit2` script (as `shunit2.sh`) and its Apache 2.0 `LICENSE` into the
project, where the tests source them. To update shUnit2, change the pinned
version and run this task again. With `--dry-run`, nothing is written.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

import mise_task

TARGET_DIR = Path("vendor/lib")
SCRIPT_TARGET = TARGET_DIR / "shunit2.sh"
LICENSE_TARGET = TARGET_DIR / "shunit2.LICENSE"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()

    found = shutil.which("shunit2")
    if found is None:
        raise mise_task.TaskError("shunit2 not found on PATH "
                                  "(is the shunit2 tool installed?)")
    script = Path(found).resolve()
    license_file = script.parent / "LICENSE"
    if not license_file.is_file():
        raise mise_task.TaskError(f"no LICENSE next to {script}")

    match = re.search(rb"^SHUNIT_VERSION='([^']+)'", script.read_bytes(),
                      re.MULTILINE)
    version = match.group(1).decode() if match else "unknown version"
    if mise_task.verbosity() >= 1:
        print(f"installed shUnit2 {version}: {script}", file=sys.stderr)

    label = f"shUnit2 {version}"
    mise_task.sync_file(script, SCRIPT_TARGET, label)
    mise_task.sync_file(license_file, LICENSE_TARGET, f"{label} license")
    return 0


if __name__ == "__main__":
    mise_task.run_main(main)
