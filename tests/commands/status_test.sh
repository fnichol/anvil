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
}

runCli() {
  run "$root/bin/anvil" "$@"
}

runCliWithConfig() {
  local config_file="$1"
  shift

  ANVIL_CONFIG_PATH="$config_file" runCli "$@"
}

testCmdStatusHelpShortFlag() {
  runCli status -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'status'
  assertStderrNull
}

testCmdStatusHelpLongFlag() {
  runCli status --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'status'
  assertStderrNull
}

testCmdStatusNoConfig() {
  runCli status

  assertFalse 'cli command passed and should have failed' "$return_status"
  assertStdoutContains 'No config found'
  assertStderrContains 'Config file not found'
}

testCmdStatusWithConfigNoTags() {
  local config_file
  config_file="$tmpdir/config.json"

  runCliWithConfig "$config_file" config init

  runCliWithConfig "$config_file" status

  assertFalse 'cli command passed and should have failed' "$return_status"
  assertStdoutContains 'Anvil Status'
  assertStdoutContains 'Operating System: '
  assertStdoutContains 'Architecture: '
  assertStdoutContains 'Operating System Version: '
  assertStderrContains 'No tags configured'
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
