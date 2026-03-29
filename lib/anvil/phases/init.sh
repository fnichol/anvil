#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/sudo.sh
. "$SRC_ROOT/lib/anvil/sudo.sh"

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

  echo "setup_traps"
  echo "validate_commands"
  echo "ensure_tools"
}

init_step_setup_traps() {
  setup_cleanups
  setup_traps trap_cleanups
}

init_step_validate_commands() {
  need_cmd basename
  need_cmd chmod
  need_cmd cut
  need_cmd date
  need_cmd dirname
  need_cmd getent
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
