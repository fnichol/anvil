#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../../.."

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

testCmdConfigEditHelpShortFlag() {
  runCli config edit -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'config edit'
  assertStderrNull
}

testCmdConfigEditHelpLongFlag() {
  runCli config edit --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'config edit'
  assertStderrNull
}

testCmdConfigEditNoConfig() {
  local config_file
  config_file="$tmpdir/nonexistent.json"

  runCliWithConfig "$config_file" config edit

  assertFalse 'cli command succeeded' "$return_status"
  assertStdoutStripAnsiContains "nonexistent.json"
  assertStdoutStripAnsiContains "Hint: "
  assertStderrStripAnsiContains "Config file does not exist"
}

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../../_ksh_local.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
