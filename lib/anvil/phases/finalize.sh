#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/hooks.sh
. "$SRC_ROOT/lib/anvil/hooks.sh"
# shellcheck source=lib/anvil/state.sh
. "$SRC_ROOT/lib/anvil/state.sh"

finalize_steps() {
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

  # Hook steps run first, before the terminal cleanup operations.
  hooks_steps_for_phase "$root" "finalize"

  # Terminal steps always run last.
  echo "record_run"
  echo "cleanup"
}

finalize_step_record_run() {
  local root="$1"
  shift
  local _config_path="$1"
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

finalize_step_cleanup() {
  # TODO: implement

  info "finalize:cleanup - stub"
}
