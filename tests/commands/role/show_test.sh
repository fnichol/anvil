#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../../.."

  commonOneTimeSetUp
}

setUp() {
  commonSetUp

  writeModuleFixture \
    "default" \
    "$root/tests/fixtures/data/tags" \
    "$root/tests/fixtures/data/roles"
  writeConfigFile \
    '{"modules":[{"name":"default","url":"https://example.com/default.git"}]}'
}

runCli() {
  run "$root/bin/anvil" "$@"
}

testCmdRoleShowHelpShortFlag() {
  runCli role show -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'role show'
  assertStderrNull
}

testCmdRoleShowHelpLongFlag() {
  runCli role show --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'role show'
  assertStderrNull
}

testCmdRoleShowNoNameFails() {
  runCli role show

  assertFalse 'cli command succeeded' "$return_status"
  assertStdoutNull
  assertStderrContains 'USAGE:'
  assertStderrContains 'role show'
  assertStderrContains 'required argument: NAME'
}

testCmdTagShowWithName() {
  runCli role show alfa

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'Role: alfa'
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
