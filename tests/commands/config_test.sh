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

testCmdConfigNoArgsShowsHlep() {
  runCli config

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'config'
  assertStderrNull
}

testCmdConfigHelpShortFlag() {
  runCli config -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'config'
  assertStderrNull
}

testCmdConfigHelpLongFlag() {
  runCli config --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'config'
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
