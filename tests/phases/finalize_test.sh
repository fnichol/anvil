#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
  . "$SRC_ROOT/lib/anvil/hooks.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/phases/finalize.sh}"
}

testFinalizeStepsAlwaysContainsRecordRunAndCleanup() {
  run finalize_steps "$tmpdir" "/dev/null" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "record_run"
  assertStdoutContains "cleanup"
}

testFinalizeStepsHookStepsAppearBeforeRecordRun() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"

  run finalize_steps "$tmpdir" "/dev/null" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"

  # Capture line numbers for hook and record_run
  local hook_line record_run_line
  hook_line="$(grep -n '^hook_tailscaled$' "$stdout" | cut -d: -f1)"
  record_run_line="$(grep -n '^record_run$' "$stdout" | cut -d: -f1)"

  assertTrue 'hook_tailscaled not found' "[ -n '$hook_line' ]"
  assertTrue 'hook must appear before record_run' \
    "[ '$hook_line' -lt '$record_run_line' ]"
}

testFinalizeStepsEmitsNoHookStepsWhenDirAbsent() {
  run finalize_steps "$tmpdir" "/dev/null" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected' \
    "grep -q '^hook_' '$stdout'"
}

testFinalizeStepsHookStepsInNumericOrderBeforeRecordRun() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/020-syncthing.sh"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"

  run finalize_steps "$tmpdir" "/dev/null" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"

  local steps
  steps="$(cat "$stdout")"

  # Verify complete order: tailscaled, syncthing, record_run, cleanup
  assertEquals 'wrong step order' \
    "$(printf 'hook_tailscaled\nhook_syncthing\nrecord_run\ncleanup')" \
    "$steps"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
