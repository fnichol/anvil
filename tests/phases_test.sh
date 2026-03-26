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

  . "${SRC:=lib/anvil/phases.sh}"
}

testSkipedWithExactMatch() {
  run _should_skip_phase_step "perform" "laundry" "perform:laundry"

  assertTrue 'exact match should skip' "$return_status"
}

testNotSkipedWithExactMismatch() {
  run _should_skip_phase_step "perform" "laundry" "save:paper"

  assertFalse 'non-matching token should not skip' "$return_status"
}

testSkipedWithPhaseWildcard() {
  run _should_skip_phase_step "save" "paper" "save:*"

  assertTrue 'phase wildcard should skip all steps in phase' "$return_status"
}

testNotSkipedWithPhaseWildcardForOtherPhase() {
  run _should_skip_phase_step "perform" "laundry" "save:*"

  assertFalse 'phase wildcard should not skip a different phase' \
    "$return_status"
}

testSkippedStepWildcard() {
  run _should_skip_phase_step "finish" "icecream" "*:icecream"

  assertTrue 'step wildcard should skip named step in all phases' \
    "$return_status"
}

testNotSkippedStepWildcardOtherStep() {
  run _should_skip_phase_step "finish" "icecream" "*:taxes"

  assertFalse 'step wildcard should not match a different step name' \
    "$return_status"
}

testSkippedGlobalWildcard() {
  run _should_skip_phase_step "perform" "laundry" "*:*"

  assertTrue 'global wildcard should skip everything' "$return_status"
}

testSkippedWithMultipleTokens() {
  run _should_skip_phase_step "perform" "laundry" "save:* perform:laundry"

  assertTrue 'should skip when one of multiple tokens matches' "$return_status"
}

testNotSkippedWithMultipleNonMatchingTokens() {
  run _phase_step_skipped "perform" "laundry" "save:* finish:icecream"

  assertFalse 'should not skip when no token matches' "$return_status"
}

testPhasesRunHookStepExecutesHookScriptAsSubprocess() {
  local hooks_dir="$tmpdir/data/hooks/finalize"
  mkdir -p "$hooks_dir"

  mkdir -p "$tmpdir/tmp"

  cat <<-'EOF' >"$hooks_dir/010-marker.sh"
	finalize_hook_marker() {
	  echo "hook_ran" >"$ANVIL_ROOT/tmp/hook_marker"
	}
	EOF

  ANVIL_ROOT="$tmpdir"
  export ANVIL_ROOT

  . "$SRC_ROOT/lib/anvil/hooks.sh"

  run _phases_run_hook_step \
    "finalize" "hook_marker" \
    "$tmpdir" "/dev/null" \
    "myhost" "arch" "rolling" "linux" "x86_64"

  assertTrue 'hook step failed' "$return_status"
  assertTrue 'hook output file not created' \
    "[ -f '$tmpdir/tmp/hook_marker' ]"
}

testPhasesRunHookStepFailsOnNonZeroHookExit() {
  local hooks_dir="$tmpdir/data/hooks/finalize"
  mkdir -p "$hooks_dir"

  cat <<-'EOF' >"$hooks_dir/010-failing.sh"
	finalize_hook_failing() {
	  return 1
	}
	EOF

  ANVIL_ROOT="$tmpdir"
  export ANVIL_ROOT

  . "$SRC_ROOT/lib/anvil/hooks.sh"

  run _phases_run_hook_step \
    "finalize" "hook_failing" \
    "$tmpdir" "/dev/null" \
    "myhost" "arch" "rolling" "linux" "x86_64"

  assertFalse 'hook step should have failed' "$return_status"
}

testPhasesRunHookStepExportsAnvilEnvVars() {
  local hooks_dir="$tmpdir/data/hooks/configure"
  mkdir -p "$hooks_dir"

  mkdir -p "$tmpdir/tmp"

  cat <<-'EOF' >"$hooks_dir/010-envcheck.sh"
	configure_hook_envcheck() {
	  printf '%s\n' "$ANVIL_OS" "$ANVIL_ARCH" >"$ANVIL_ROOT/tmp/envcheck"
	}
	EOF

  ANVIL_ROOT="$tmpdir"
  export ANVIL_ROOT

  . "$SRC_ROOT/lib/anvil/hooks.sh"

  run _phases_run_hook_step \
    "configure" "hook_envcheck" \
    "$tmpdir" "/dev/null" \
    "myhost" "testarch_os" "1.0" "linux" "testarch_arch"

  assertTrue 'hook step failed' "$return_status"
  assertTrue 'env check file missing' \
    "[ -f '$tmpdir/tmp/envcheck' ]"
  assertTrue 'ANVIL_OS not set in hook' \
    "grep -q 'testarch_os' '$tmpdir/tmp/envcheck'"
  assertTrue 'ANVIL_ARCH not set in hook' \
    "grep -q 'testarch_arch' '$tmpdir/tmp/envcheck'"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "$shunit2"
