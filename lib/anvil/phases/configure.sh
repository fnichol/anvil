#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/hooks.sh
. "$SRC_ROOT/lib/anvil/hooks.sh"

configure_steps() {
  local config_file="$1"
  shift
  local data_home="$1"
  shift
  local os="$1"
  shift
  local _version="$1"
  shift
  local _kernel="$1"
  shift
  local arch="$1"
  shift

  # Built-in configure steps go here as they are implemented.
  #
  # **Note**: hook steps should follow any built-in steps.
  hooks_steps_for_phase \
    "$config_file" \
    "$data_home" \
    "$os" \
    "$arch" \
    "configure" \
    "$(config_resolve_tags "$config_file" "$data_home")"
}
