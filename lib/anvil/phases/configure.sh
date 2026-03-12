#!/usr/bin/env sh
# shellcheck disable=SC3043

configure_steps() {
  local _root="$1"
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

  echo "something"
}

configure_step_something() {
  # TODO: determine what to configure, name it, and implement

  info "configure:something - stub"
}
