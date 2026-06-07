#!/usr/bin/env sh
# shellcheck disable=SC3043

# Runs command with root privileges.
#
# * `@param [String[]]` command and arguments
# * `@return` the exit code of the command which was executed
#
# # Global Variables
#
# * `__ANVIL_SUDO__`: contains the computed command to invoke, typically `sudo`
#    or `doas` depending on the platform. May also contain value of
#    `__disabled__` which signals the command should *not* be executed.
as_root() {
  case "${__ANVIL_SUDO__:-}" in
    "")
      "$@"
      ;;
    __disabled__)
      die "Privilege elevation disabled (--no-sudo); refusing to run: $*"
      ;;
    *)
      "$__ANVIL_SUDO__" "$@"
      ;;
  esac
}

# Detects a suitable sudo program for the system and the current user.
#
# # Global Variables
#
# * `__ANVIL_SUDO__`: sets the computed command to invoke, typically `sudo` or
#   `doas` depending on the platform
detect_sudo() {
  # Early return if sudo behavior is disabled
  if [ "${__ANVIL_SUDO__:-}" = "__disabled__" ]; then
    return 0
  fi

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
}

# Aquires an initial sudo/doas session.
get_sudo() {
  local hostname="$1"

  need_cmd basename

  case "$(basename "$__ANVIL_SUDO__")" in
    doas)
      "$__ANVIL_SUDO__" true
      ;;
    sudo)
      "$__ANVIL_SUDO__" \
        -v \
        -p "[sudo required for some tasks] Password for %u@$hostname: "
      ;;
  esac
}

# Keeps an existing sudo/doas timestamp updated for the rest of the process.
#
# Thanks to @cowboy for the inspiration: https://gist.github.com/cowboy/3118588
keep_sudo() {
  need_cmd basename

  case "$(basename "$__ANVIL_SUDO__")" in
    doas)
      while true; do
        "$__ANVIL_SUDO__" true
        sleep 59
        kill -0 "$$" || exit
      done 2>/dev/null &
      ;;
    sudo)
      while true; do
        "$__ANVIL_SUDO__" -n true
        sleep 59
        kill -0 "$$" || exit
      done 2>/dev/null &
      ;;
  esac
}
