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

testCmdModuleNoArgsShowsHlep() {
  runCli module

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module'
  assertStderrNull
}

testCmdModuleHelpShortFlag() {
  runCli module -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module'
  assertStderrNull
}

testCmdModuleHelpLongFlag() {
  runCli module --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStderrNull
}

testCmdModuleUnknownSubcommandFails() {
  runCli module unknowncmd
  debugLastRun

  assertFalse 'should fail for unknown subcommand' "$return_status"
  assertStderrContains 'unknown subcommand'
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
