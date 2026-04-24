#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp
}

setUp() {
  commonSetUp

  test_config="$tmpdir/config.json"
}

runCli() {
  ANVIL_CONFIG_PATH="$test_config" __ANVIL_LOGGING__=1 \
    run "$root/bin/anvil" "$@"
}

testCmdConfigHelpShortFlag() {
  runCli apply -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'apply'
  assertStderrNull
}

testCmdConfigHelpLongFlag() {
  runCli apply --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'apply'
  assertStderrNull
}

testCmdApplyNoConfigShowsError() {
  runCli apply

  assertFalse 'apply should fail without config' "$return_status"
  assertStdoutContains 'No config found at:'
  assertStderrContains 'Config file not found'
}

testApplyDryRunWithConfig() {
  # Create minimal config
  cat >"$test_config" <<-'EOF'
	{
	  "modules": [{"name":"foo","url":"https://example.com"}],
	  "tags": ["alfa"],
	  "skip_steps": [],
	  "custom_packages": {
	    "add": [],
	    "remove": []
	  }
	}
	EOF
  writeModuleFixture "foo" "$root/tests/fixtures/data/tags"

  runCli apply --dry-run

  assertTrue 'apply --dry-run should succeeed' "$return_status"
  # TODO: this may come back, depending on output of re-assembled functionality
  #
  # # Should show either packages to install or "converged" message
  # assertTrue 'Missing expected output' \
  #   "cat '$stdout' | grep -qE '(Would Install|System Converged|No changes)'"
}

testCmdApplyFailsWithNoModules() {
  echo '{"modules":[]}' >"$test_config"

  runCli apply

  assertFalse 'should fail with no modules' "$return_status"
  assertStdoutContains 'No modules are installed'
  assertStderrContains 'Nothing configured to apply'
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
