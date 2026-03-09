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
#    or `doas` depending on the platform
as_root() {
  if [ -n "$__ANVIL_SUDO__" ]; then
    "$__ANVIL_SUDO__" "$@"
  else
    "$@"
  fi
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
