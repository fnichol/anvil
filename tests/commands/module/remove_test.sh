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

testCmdModuleRemoveHelpShortFlag() {
  runCli module remove -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module remove'
  assertStderrNull
}

testCmdModuleRemoveHelpLongFlag() {
  runCli module remove --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module remove'
  assertStderrNull
}

testCmdModuleRemoveFailsForUnknownModule() {
  writeConfigFile '{"modules":[]}'

  runCli module remove nonexistent

  assertFalse 'should fail for unregistered module' "$return_status"
  assertStderrContains 'not present'
}

testCmdModuleRemoveDeletesDirectoryAndConfig() {
  writeConfigFile \
    '{"modules":[{"name":"mypkg","url":"https://github.com/user/mypkg.git"}]}'
  writeModuleFixture "mypkg"

  runCli module remove mypkg

  assertTrue 'cli command failed' "$return_status"

  local config_file
  config_file="$HOME/.config/anvil/config.json"
  assertJsonFromFile "$config_file" '.modules | length == 0'
  assertFalse 'module dir should be gone' \
    "[ -d '${HOME}/.local/share/anvil/modules/mypkg' ]"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
