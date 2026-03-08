#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../vendor/lib/libsh.full.sh"
  . "${SRC:=lib/anvil/phases.sh}"

  commonOneTimeSetUp
}

setUp() {
  commonSetUp
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

shell_compat "$0"

. "$shunit2"
