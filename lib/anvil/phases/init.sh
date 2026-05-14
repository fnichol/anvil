#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/sudo.sh
. "$SRC_ROOT/lib/anvil/sudo.sh"

init_steps() {
  local _config_file="$1"
  shift
  local _data_home="$1"
  shift
  local _os="$1"
  shift
  local _version="$1"
  shift
  local _kernel="$1"
  shift
  local _arch="$1"
  shift

  echo "setup_traps"
  echo "sanitize_environment"
  echo "validate_commands"
  echo "ensure_tools"
}

init_step_setup_traps() {
  setup_cleanups
  setup_traps trap_cleanups
}

init_step_sanitize_environment() {
  # If Mise is installed and activated, deactivate it to remove Mise-managed
  # tools from PATH.
  #
  # We want to ensure that any source-built packages (such as Arch Linux AUR
  # packages) are built with system package dependencies to minimize surprises.
  if [ -x "$HOME/.local/bin/mise" ] && [ -n "${__MISE_EXE:-}" ]; then
    info "Deactivating mise for remainder of command session"
    { eval "$("$HOME/.local/bin/mise" deactivate)"; } >/dev/null 2>&1
  fi
}

init_step_validate_commands() {
  need_cmd basename
  need_cmd chmod
  need_cmd cut
  need_cmd date
  need_cmd dirname
  need_cmd grep
  need_cmd gzip
  need_cmd id
  need_cmd ln
  need_cmd mkdir
  need_cmd sed
  need_cmd sort
  need_cmd tar
  need_cmd tr
  need_cmd uname

  case "$(uname -s)" in
    Darwin)
      # getent not present on stock macOS
      ;;
    *)
      need_cmd getent
      ;;
  esac

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

init_step_ensure_tools() {
  ensure_jq
}
