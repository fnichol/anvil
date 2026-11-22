#!/usr/bin/env sh
# shellcheck disable=SC3043

# shuck: source=../../_ksh_local.sh
. "${0%/*}/../../_ksh_local.sh"

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

testCmdRoleListHelpShortFlag() {
  runCli role list -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'role list'
  assertStderrNull
}

testCmdRoleListHelpLongFlag() {
  runCli role list --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'role list'
  assertStderrNull
}

# shuck: source=../../test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

# shuck: source=../../../vendor/lib/shunit2.sh
. "${0%/*}/../../../$shunit2RelRoot"
