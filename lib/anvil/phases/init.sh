#!/usr/bin/env sh
# shellcheck disable=SC3043

init_steps() {
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

  echo "validate_commands"
  echo "detect_privilege"
  echo "acquire_sudo"
  echo "ensure_tools"
}

init_step_validate_commands() {
  need_cmd basename
  need_cmd chmod
  need_cmd dirname
  need_cmd gzip
  need_cmd id
  need_cmd ln
  need_cmd mkdir
  need_cmd sed
  need_cmd tar
  need_cmd tr
  need_cmd uname

  # Facts phase hasn't been run, so we'll check the kernel ourselves
  case "$(uname -s)" in
    OpenBSD)
      # At least one download tool must be present
      if ! check_cmd curl && ! check_cmd wget && ! check_cmd ftp; then
        err "Either 'curl', 'wget', or 'ftp' is required but none was found."
        err "Install one and re-run:"
        err "    - https://curl.se"
        err "    - https://www.gnu.org/software/wget/"
        return 1
      fi
      ;;
    *)
      # At least one download tool must be present
      if ! check_cmd curl && ! check_cmd wget; then
        err "Either 'curl' or 'wget' is required but neither was found."
        err "Install one and re-run:"
        err "    - https://curl.se"
        err "    - https://www.gnu.org/software/wget/"
        return 1
      fi
      ;;
  esac

  info "All required commands present"
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

init_step_ensure_tools() {
  ensure_jq
}
