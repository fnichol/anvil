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

  : "${SRC:=lib/anvil/hook_runner.sh}"

  ANVIL_ROOT="$SRC_ROOT"
  export ANVIL_ROOT
}

testHookRunnerSetsAnvilHookSupport() {
  run_in_sh_script <<-'EOF'
	. "$ANVIL_ROOT/lib/anvil/hook_runner.sh"
	echo "$ANVIL_HOOK_SUPPORT"
	EOF

  assertTrue 'hook_runner.sh failed to source' "$return_status"
  assertStdoutContains "hook_support.sh"
}

testHookRunnerAnvilHookSupportPathExists() {
  run_in_sh_script <<-'EOF'
	. "$ANVIL_ROOT/lib/anvil/hook_runner.sh"
	test -f "$ANVIL_HOOK_SUPPORT"
	EOF

  assertTrue 'ANVIL_HOOK_SUPPORT path does not exist' "$return_status"
}

testHookRunnerAnvilHookSupportIsExported() {
  run_in_sh_script <<-'EOF'
	. "$ANVIL_ROOT/lib/anvil/hook_runner.sh"
	# exported vars appear in env output of a subshell
	sh -c 'echo $ANVIL_HOOK_SUPPORT' | grep -q "hook_support.sh"
	EOF

  assertTrue 'ANVIL_HOOK_SUPPORT not exported' "$return_status"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../$shunit2RelRoot"
