#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/state.sh}"

  # Override XDG_STATE_HOME to an isolated tmpdir for every test
  export XDG_STATE_HOME="$tmpdir/state"
}

testStatePathRespectsXdgStateHome() {
  run state_path

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "$tmpdir/state/anvil/state.json"
  assertStderrNull
}

testWriteLastRunCreatesFile() {
  local state_file="$tmpdir/state/anvil/state.json"

  assertFalse 'state file should not exist yet' "[ -f '$state_file' ]"

  run state_write_last_run "2026-02-01T12:01:02Z"

  assertTrue 'function failed' "$return_status"
  assertTrue 'state file should now exist' "[ -f '$state_file' ]"
  assertJsonFromFile "$state_file" '.last_run == "2026-02-01T12:01:02Z"'
}

testWriteLastRunUpdatesExistingFile() {
  state_write_last_run "2026-01-01T00:00:00Z"

  run state_write_last_run "2026-02-01T12:01:02Z"

  local state_file="$tmpdir/state/anvil/state.json"
  assertTrue 'function failed' "$return_status"
  assertJsonFromFile "$state_file" '.last_run == "2026-02-01T12:01:02Z"'
}

testReadLastRun() {
  run state_write_last_run "2026-02-01T12:01:02Z"

  run state_read_last_run

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "2026-02-01T12:01:02Z"
  assertStderrNull
}

testReadLastRunMissingFile() {
  run state_read_last_run

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testUpdateCheckIsDueWhenNoStateFile() {
  local state_file="$tmpdir/state/anvil/state.json"

  assertFalse 'state file should not exist' "[ -f '$state_file' ]"

  run state_is_update_check_due

  assertTrue 'check should be due when no state file' "$return_status"
  assertStderrNull
}

testUpdateCheckIsDueWhenNextTsIsInPast() {
  local past_ts
  past_ts="$(($(date -u +%s) - 1))"

  state_write_update_check "0.1.0" "$past_ts"

  run state_is_update_check_due

  assertTrue 'check should be due when next_ts is past' "$return_status"
  assertStderrNull
}

testUpdateCheckIsNotDueWhenNextTsIsInFuture() {
  local future_ts
  future_ts="$(($(date -u +%s) + 86400))"

  state_write_update_check "0.1.0" "$future_ts"

  run state_is_update_check_due

  assertFalse 'check should not be due when next_ts is future' "$return_status"
  assertStderrNull
}

testWriteUpdateCheckCreatesFields() {
  local state_file="$tmpdir/state/anvil/state.json"
  local future_ts="$(($(date -u +%s) + 86400))"

  run state_write_update_check "0.2.0" "$future_ts"

  assertTrue 'function should succeed' "$return_status"
  assertTrue 'state file should exist' "[ -f '$state_file' ]"
  assertJsonFromFile "$state_file" '.latest_known_version == "0.2.0"'
  assertJsonFromFile "$state_file" ".next_update_check_ts == $future_ts"
}

testReadLatestKnownVersionReturnsEmpty() {
  run state_read_latest_known_version

  assertTrue 'function should succeed' "$return_status"
  assertStdoutEquals ''
  assertStderrNull
}

testReadLatestKnownVersionReturnsStoredVersion() {
  state_write_update_check "0.2.0" "$(($(date -u +%s) + 86400))"

  run state_read_latest_known_version

  assertTrue 'function should succeed' "$return_status"
  assertStdoutEquals '0.2.0'
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "$shunit2"
