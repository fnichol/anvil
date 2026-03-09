#!/usr/bin/env sh
# shellcheck disable=SC3043

init_steps() {
  echo "validate_commands"
  echo "detect_privilege"
  echo "acquire_sudo"
}

init_step_validate_commands() {
  # TODO: verify all required commands are present

  info "init:validate_commands - stub"
}

init_step_detect_privilege() {
  need_cmd id
  need_cmd uname

  if [ "$(id -u)" -eq 0 ]; then
    __ANVIL_SUDO__=""
    info "Running as root; privilege elevation not required"
    return 0
  fi

  # Facts phase hasn't been run, so we'll check the kernel ourselves
  case "$(uname -s)" in
    OpenBSD)
      need_cmd doas
      __ANVIL_SUDO__="doas"
      ;;
    *)
      need_cmd sudo
      __ANVIL_SUDO__="sudo"
      ;;
  esac

  info "Privilege elevation command: $__ANVIL_SUDO__"
}

init_step_acquire_sudo() {
  local _root="$1"
  shift
  local _config_file="$1"
  shift
  local hostname="$1"
  shift

  # If root user was detect, early return
  if [ -z "${__ANVIL_SUDO__:-}" ]; then
    info "Running as root; $__ANVIL_SUDO__ keepalive not required"
    return 0
  fi

  get_sudo "${hostname:-unknown-host}"
  keep_sudo

  info "Running $__ANVIL_SUDO__ keepalive in background"
}
