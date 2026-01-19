#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  commonOneTimeSetUp
  root="${0%/*}/../.."
}

setUp() {
  commonSetUp
}

runCli() {
  run "$root/bin/anvil" "$@"
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

testCmdStatus() {
  runCli status

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'Anvil Status'
  assertStdoutContains 'Operating System: '
  assertStdoutContains 'Tags: '
  assertStdoutContains 'Desired Packages: '
  assertStdoutContains 'Installed Packages: '
  assertStdoutContains 'Pending Installs: '
  assertStderrNull
}

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
