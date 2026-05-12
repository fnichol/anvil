#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/facts.sh
. "$SRC_ROOT/lib/anvil/facts.sh"

# Re-execs the current process under `script` for full PTY logging.
#
# This implementation detects if it's already running inside a `script` session
# to prevent infinite recursion.
#
# * `@param [String]` prefix - log file prefix (e.g. "anvil-apply")
# * `@param [String[]]` cmd [args...] - the binary and args to re-exec
#
# # Global Variables
#
# * `__ANVIL_LOGGING__`: sentinel that prevents an infinite re-exec
logging_exec() {
  local prefix="$1"
  shift

  if [ -n "${__ANVIL_LOGGING__:-}" ]; then
    return 0
  fi

  need_cmd date
  need_cmd grep
  need_cmd mkdir
  need_cmd script

  local log_file
  log_file="$(_logging_file "$prefix")"

  mkdir -p "$(_logging_path)"

  echo
  info "Logging to $log_file"
  echo

  case "$(facts_kernel)" in
    openbsd)
      __ANVIL_LOGGING__=1 exec script -c "$*" "$log_file"
      ;;
    *)
      # Detect GNU script (Linux/Alpine) vs BSD script (macOS/FreeBSD).
      #
      # - GNU program style script uses `-c <cmd-string> <logfile>`
      # - BSD program style script uses `<logfile> <cmd> [args]`.
      #
      # This detection is ported from the legacy bin/log script.
      if { script -h || true; } 2>&1 | grep -q '\-c[, \t]'; then
        __ANVIL_LOGGING__=1 exec script -q -c "$*" "$log_file"
      else
        __ANVIL_LOGGING__=1 exec script -q "$log_file" "$@"
      fi
      ;;
  esac
}

# Returns the logging directory home for Anvil.
#
# The path is determined using the XDG Base Directory specification, falling
# back to the `~/.local/state` if not set.
#
# * `@stdout` logging directory path
# * `@return 0` if successful
#
# # Environment Variables
#
# * `XDG_STATE_HOME` used to determine the logging directory home, defaults to
#   `$HOME/.local/state` if not set
# * `HOME` used as fallback when `XDG_STATE_HOME` is not set
_logging_path() {
  echo "${XDG_STATE_HOME:-$HOME/.local/state}/anvil/logs"
}

# Computes the full path for a timestamped log file with the given prefix.
#
# * `@param [String]` prefix (e.g. "anvil-apply")
_logging_file() {
  local prefix="$1"

  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"

  echo "$(_logging_path)/${prefix}-${timestamp}.log"
}
