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

testCmdSelfNoArgsShowsHelp() {
  runCli self

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'self'
  assertStderrNull
}

testCmdSelfHelpShortFlag() {
  runCli self -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'self'
  assertStderrNull
}

testCmdSelfHelpLongFlag() {
  runCli self --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStderrNull
}

testCmdSelfUnknownSubcommandFails() {
  runCli self unknowncmd

  assertFalse 'should fail for unknown subcommand' "$return_status"
  assertStderrContains 'unknown subcommand'
}

testTopLevelHelpMentionsSelf() {
  runCli --help

  assertTrue 'anvil --help failed' "$return_status"
  assertStdoutContains 'self'
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
