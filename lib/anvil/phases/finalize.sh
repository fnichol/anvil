#!/usr/bin/env sh
# shellcheck disable=SC3043

finalize_steps() {
  echo "record_run"
  echo "cleanup"
}

finalize_step_record_run() {
  local _root="$1"
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

  # shellcheck source=lib/anvil/jq.sh
  . "$root/lib/anvil/jq.sh"
  # shellcheck source=lib/anvil/state.sh
  . "$root/lib/anvil/state.sh"

  state_write_last_run
}

finalize_step_cleanup() {
  # TODO: implement

  info "finalize:cleanup - stub"
}
