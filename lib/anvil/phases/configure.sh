#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/hooks.sh
. "$SRC_ROOT/lib/anvil/hooks.sh"

configure_steps() {
  local root="$1"
  shift
  local _config_path="$1"
  shift
  local _os="$1"
  shift
  local _version="$1"
  shift
  local _kernel="$1"
  shift
  local _arch="$1"
  shift

  # Built-in configure steps go here as they are implemented.
  #
  # **Note**: hook steps should follow any built-in steps.
  hooks_steps_for_phase "$root" "configure"
}
