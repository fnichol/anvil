#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/hooks.sh
. "$SRC_ROOT/lib/anvil/hooks.sh"
# shellcheck source=lib/anvil/state.sh
. "$SRC_ROOT/lib/anvil/state.sh"

finalize_steps() {
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

  # Hook steps run first, before the terminal cleanup operations.
  hooks_steps_for_phase \
    "$config_file" \
    "$data_home" \
    "$os" \
    "$arch" \
    "finalize" \
    "$(config_resolve_tags "$config_file" "$data_home")"

  # Terminal steps always run last.
  echo "record_run"
}

finalize_step_record_run() {
  local _config_file="$1"
  shift
  local _data_home="$1"
  shift
  local _hostname="$1"
  shift
  local _os="$1"
  shift
  local _version="$1"
  shift
  local _kernel="$1"
  shift
  local _arch="$1"
  shift

  state_write_last_run
}
