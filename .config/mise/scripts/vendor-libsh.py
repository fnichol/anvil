#!/usr/bin/env python3
"""Vendors libsh into vendor/lib/libsh.full.sh (task: vendor:libsh).

The release is the one pinned by `tool_version_libsh` in
`conf.d/vars-tool-version.toml`: Mise installs it as a tool, and this copies
the installed file into the project. To update libsh, change the pinned
version and run this task again. With `--dry-run`, nothing is written.
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

import mise_task

ASSET = "libsh.full.sh"
TARGET = Path("vendor/lib") / ASSET


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()

    found = shutil.which(ASSET)
    if found is None:
        raise mise_task.TaskError(f"{ASSET} not found on PATH "
                                  "(is the libsh tool installed?)")
    installed = Path(found).resolve()
    data = installed.read_bytes()

    match = re.search(rb"^# version: (\S+)$", data, re.MULTILINE)
    version = match.group(1).decode() if match else "unknown version"
    if mise_task.verbosity() >= 1:
        print(f"installed libsh {version}: {installed}", file=sys.stderr)

    mise_task.sync_file(installed, TARGET, f"libsh {version}")
    return 0


if __name__ == "__main__":
    mise_task.run_main(main)
