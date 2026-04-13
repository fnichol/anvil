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
}

runCli() {
  run "$root/bin/anvil" "$@"
}

testCmdModuleListHelpShortFlag() {
  runCli module list -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStderrNull
}

testCmdModuleListHelpLongFlag() {
  runCli module list --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStderrNull
}

testCmdModuleListEmptyWhenNoModules() {
  writeConfigFile '{"modules":[]}'

  runCli module list

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'No modules registered'
  assertStderrNull
}

testCmdModuleListShowsRegisteredModules() {
  writeConfigFile \
    '{"modules":[{"name":"mypkg","url":"https://github.com/user/mypkg.git"}]}'
  writeModuleFixture "mypkg"

  runCli module list

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'mypkg'
  assertStdoutContains 'github.com'
  assertStderrNull
}

testCmdModuleListShowsNotInstalledStatus() {
  writeConfigFile \
    '{"modules":[{"name":"mypkg","url":"https://github.com/user/mypkg.git"}]}'
  # Note: skip writeModuleFixture as we want to simulate the module dir that
  # does not exist

  runCli module list

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'mypkg'
  assertStdoutContains 'not installed'
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
