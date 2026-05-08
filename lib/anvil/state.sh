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
    cleanup_file "$tmp_state"

    jq \
      --arg timestamp "$timestamp" \
      '.last_run = $timestamp' \
      "$state_file" \
      >"$tmp_state"

    cat "$tmp_state" >"$state_file"
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

# Writes a fetched_at timestamp for a module to the state file.
#
# * `@param [String]` module name
# * `@param [optional, String]` ISO 8601 timestamp, defaults to current time
# * `@return 0` if successful
state_write_module_fetched_at() {
  need_cmd date
  need_cmd mkdir

  ensure_jq

  local name="$1"
  local timestamp="${2:-$(date -u +%FT%TZ)}"

  local state_file
  state_file="$(state_path)"

  mkdir -p "$(dirname "$state_file")"

  if [ -f "$state_file" ]; then
    local tmp_state
    tmp_state="$(mktemp_file)"
    cleanup_file "$tmp_state"

    jq \
      --arg name "$name" \
      --arg ts "$timestamp" \
      '(.modules // []) |= map(if .name == $name then .fetched_at = $ts else . end)
       | if ([.modules[]? | select(.name == $name)] | length) == 0
         then .modules += [{"name": $name, "fetched_at": $ts}]
         else . end' \
      "$state_file" \
      >"$tmp_state"

    cat "$tmp_state" >"$state_file"
  else
    jq -n \
      --arg name "$name" \
      --arg ts "$timestamp" \
      '{modules: [{"name": $name, "fetched_at": $ts}]}' \
      >"$state_file"
  fi
}

# Reads the fetched_at timestamp for a module from the state file.
#
# * `@param [String]` module name
# * `@stdout` ISO 8601 timestamp, or empty if not present
# * `@return 0` if successful
state_read_module_fetched_at() {
  local name="$1"

  local state_file
  state_file="$(state_path)"

  if [ -f "$state_file" ]; then
    ensure_jq

    jq -r --arg name "$name" \
      '.modules[]? | select(.name == $name) | .fetched_at // empty' \
      "$state_file"
  fi
}

# Writes update check cache fields to state.json.
#
# * `@param [String]` latest known version string (e.g. "0.2.0")
# * `@param [optional, Integer]` next check Unix epoch timestamp; defaults to
#   now + 86400 (24 hours)
# * `@return 0` if successful
state_write_update_check() {
  need_cmd date
  need_cmd mkdir

  local latest_version="$1"
  local next_ts="${2:-$(($(date -u +%s) + 86400))}"

  ensure_jq

  local state_file
  state_file="$(state_path)"

  if [ -f "$state_file" ]; then
    local tmp_state
    tmp_state="$(mktemp_file)"
    cleanup_file "$tmp_state"

    jq \
      --arg v "$latest_version" \
      --argjson ts "$next_ts" \
      '.latest_known_version = $v | .next_update_check_ts = $ts' \
      "$state_file" \
      >"$tmp_state"
    cat "$tmp_state" >"$state_file"
  else
    mkdir -p "$(dirname "$state_file")"

    jq -n \
      --arg v "$latest_version" \
      --argjson ts "$next_ts" \
      '{latest_known_version: $v, next_update_check_ts: $ts}' \
      >"$state_file"
  fi
}

# Determines whether an update check should be performed.
#
# * `@return 0` if check is due or no cache exists
# * `@return 1` if check is not yet due
state_is_update_check_due() {
  local state_file
  state_file="$(state_path)"

  # Early return if no state file exists--we can infer that a check is
  # warranted.
  if [ ! -f "$state_file" ]; then
    return 0
  fi

  ensure_jq

  local next_ts
  next_ts="$(jq -r '.next_update_check_ts // 0' "$state_file")"

  [ "$(date +%s)" -ge "$next_ts" ]
}

# Reads the latest known version from the state file.
#
# * `@stdout` version string, or empty if not present
# * `@return 0` if successful
state_read_latest_known_version() {
  local state_file
  state_file="$(state_path)"

  if [ -f "$state_file" ]; then
    ensure_jq

    jq -r '.latest_known_version // empty' "$state_file"
  fi
}
