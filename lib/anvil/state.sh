#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"

# Returns the state directory home for Anvil.
#
# The path is determined using the XDG Base Directory specification, falling
# back to the `~/.local/state` if not set.
#
# * `@stdout` state home path
# * `@return 0` if successful
#
# # Environment Variables
#
# * `XDG_STATE_HOME` used to determine the state directory home, defaults to
#   `$HOME/.local/state` if not set
# * `HOME` used as fallback when `XDG_STATE_HOME` is not set
state_home() {
  echo "${XDG_STATE_HOME:-$HOME/.local/state}/anvil"
}

# Returns the path to the state file.
#
# * `@stdout` state file path
# * `@return 0` if successful
state_path() {
  echo "$(state_home)/state.json"
}

# Writes a last run timestamp to the state file.
#
# * `@param [optional, String]` ISO 8601 timestamp string, or current time if
#    unset
# * `@return 0` if successful
state_write_last_run() {
  need_cmd date
  need_cmd mkdir

  ensure_jq

  local timestamp="${1:-$(date -u +%FT%TZ)}"
  local state_file tmp_state

  state_file="$(state_path)"

  mkdir -p "$(dirname "$state_file")"

  if [ -f "$state_file" ]; then
    tmp_state="$(mktemp_file)"

    jq \
      --arg timestamp "$timestamp" \
      '.last_run = $timestamp' \
      "$state_file" \
      >"$tmp_state"

    mv "$tmp_state" "$state_file"
  else
    jq -n --arg timestamp "$timestamp" \
      '{last_run: $timestamp}' \
      >"$state_file"
  fi
}

# Reads the last run timestamp from the state file.
#
# * `@stdout` ISO 8601 timestamp, or empty if state file does not exist
# * `@return 0` if successful
state_read_last_run() {
  local state_file
  state_file="$(state_path)"

  if [ -f "$state_file" ]; then
    ensure_jq

    jq -r '.last_run // empty' "$state_file"
  fi
}
