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

  : "${SRC:=lib/anvil/hook_support.sh}"

  ANVIL_ROOT="$SRC_ROOT"
  export ANVIL_ROOT
}

testHookSupportDefinesInfoFunction() {
  run_in_sh_script <<-'EOF'
	. "$ANVIL_ROOT/lib/anvil/hook_support.sh"
	type info
	EOF

  assertTrue 'hook_support.sh failed to load' "$return_status"
}

testHookSupportDefinesAsRootFunction() {
  run_in_sh_script <<-'EOF'
	. "$ANVIL_ROOT/lib/anvil/hook_support.sh"
	type as_root
	EOF

  assertTrue 'as_root not defined' "$return_status"
}

testHookSupportAsRootRunsCommandDirectlyWhenNoSudo() {
  run_in_sh_script <<-'EOF'
	unset __ANVIL_SUDO__
	. "$ANVIL_ROOT/lib/anvil/hook_support.sh"
	as_root echo "hello"
	EOF

  assertTrue 'as_root failed' "$return_status"
  assertStdoutContains "hello"
}

testHookSupportAsRootUsesSudoWhenSet() {
  run_in_sh_script <<-'EOF'
	__ANVIL_SUDO__="echo"
	export __ANVIL_SUDO__
	. "$ANVIL_ROOT/lib/anvil/hook_support.sh"
	as_root SUDO_PREFIX
	EOF

  assertTrue 'as_root failed' "$return_status"
  assertStdoutContains "SUDO_PREFIX"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../$shunit2RelRoot"
