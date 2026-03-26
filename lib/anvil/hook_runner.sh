#!/usr/bin/env sh
# shellcheck disable=SC3043

# Per-hook subprocess preamble.
#
# Sourced first in every hook subprocess invocation before the hook script
# itself is sourced.
#
# Sets up the minimum execution environment:
#   - Enforces fail-fast behaviour (set -eu)
#   - Exports ANVIL_HOOK_SUPPORT so hook scripts can opt into helpers
#
# ANVIL_ROOT is already exported by the parent process before this runs.

set -eu

ANVIL_HOOK_SUPPORT="$ANVIL_ROOT/lib/anvil/hook_support.sh"
export ANVIL_HOOK_SUPPORT
