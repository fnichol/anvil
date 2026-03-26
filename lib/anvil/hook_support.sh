#!/usr/bin/env sh
# shellcheck disable=SC3043

# Optional helper library for Anvil hook scripts.
#
# Hook scripts source this file via:
#
#   . "$ANVIL_HOOK_SUPPORT"
#
# This provides logging helpers (info, warn, section, indent) and the as_root
# privilege-escalation function. ANVIL_ROOT must be set (it is exported by the
# hook runner before any hook script is sourced).

# shellcheck source=vendor/lib/libsh.full.sh
. "$ANVIL_ROOT/vendor/lib/libsh.full.sh"
# shellcheck source=lib/anvil/sudo.sh
. "$ANVIL_ROOT/lib/anvil/sudo.sh"
