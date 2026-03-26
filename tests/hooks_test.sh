#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/hooks.sh}"
}

testHooksStepsForPhaseEmitsNothingWhenDirAbsent() {
  run hooks_steps_for_phase "$tmpdir/no-such-root" "finalize"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
}

testHooksStepsForPhaseEmitsNothingWhenDirEmpty() {
  mkdir -p "$tmpdir/data/hooks/finalize"

  run hooks_steps_for_phase "$tmpdir" "finalize"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
}

testHooksStepsForPhaseDerivesStepNameFromFilename() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"

  run hooks_steps_for_phase "$tmpdir" "finalize"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "hook_tailscaled"
}

testHooksStepsForPhaseConvertsHyphensToUnderscores() {
  mkdir -p "$tmpdir/data/hooks/configure"
  touch "$tmpdir/data/hooks/configure/010-ssh-keys.sh"

  run hooks_steps_for_phase "$tmpdir" "configure"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "hook_ssh_keys"
}

testHooksStepsForPhaseReturnsInNumericOrder() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/020-syncthing.sh"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"

  run hooks_steps_for_phase "$tmpdir" "finalize"

  assertTrue 'function failed' "$return_status"
  assertEquals 'wrong order' \
    "$(printf 'hook_tailscaled\nhook_syncthing')" \
    "$(cat "$stdout")"
}

testHooksScriptForStepReturnsPathForMatchingName() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"

  run hooks_script_for_step "$tmpdir" "finalize" "tailscaled"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "010-tailscaled.sh"
}

testHooksScriptForStepFailsWhenNameNotFound() {
  mkdir -p "$tmpdir/data/hooks/finalize"

  run hooks_script_for_step "$tmpdir" "finalize" "nonexistent"

  assertFalse 'function should have failed' "$return_status"
}

testHooksScriptForStepMatchesHyphenatedFilenameByUnderscoredName() {
  mkdir -p "$tmpdir/data/hooks/configure"
  touch "$tmpdir/data/hooks/configure/010-ssh-keys.sh"

  run hooks_script_for_step "$tmpdir" "configure" "ssh_keys"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "010-ssh-keys.sh"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../$shunit2RelRoot"
