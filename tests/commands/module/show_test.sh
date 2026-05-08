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

testCmdModuleShowHelpShortFlag() {
  runCli module show -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module show'
  assertStderrNull
}

testCmdModuleShowHelpLongFlag() {
  runCli module show --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module show'
  assertStderrNull
}

testCmdModuleShowFailsWithNoName() {
  runCli module show

  assertFalse 'should fail without name' "$return_status"
  assertStderrContains 'NAME'
}

testCmdModuleShowDisplaysMetadata() {
  writeConfigFile \
    '{"modules":[{"name":"mypkg","url":"https://github.com/user/mypkg.git"}]}'
  writeModuleFixture \
    "mypkg" \
    "$root/tests/fixtures/data/tags" \
    "$root/tests/fixtures/data/roles"

  # Write a module.json with full metadata
  local mod_dir
  mod_dir="${HOME}/.local/share/anvil/modules/mypkg"
  printf '{"name":"mypkg","description":"My test module","min_anvil_version":"0.1.0"}\n' \
    >"$mod_dir/module.json"

  runCli module show mypkg

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'mypkg'
  assertStdoutContains 'My test module'
  assertStderrNull
}

testCmdModuleShowFailsForUnregisteredModule() {
  writeConfigFile '{"modules":[]}'

  runCli module show ghost

  assertFalse 'should fail for unknown module' "$return_status"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
