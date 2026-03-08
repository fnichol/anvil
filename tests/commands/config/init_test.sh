#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../../_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../../../vendor/lib/libsh.full.sh"

  commonOneTimeSetUp
  root="${0%/*}/../../.."

  # shellcheck source=lib/anvil/jq.sh
  . "$root/lib/anvil/jq.sh"
  # shellcheck source=lib/anvil/config.sh
  . "$root/lib/anvil/config.sh"
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

testCmdConfigInitHelpShortFlag() {
  runCli config init -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'config init'
}

testCmdConfigInitHelpLongFlag() {
  runCli config init --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'config init'
}

testCmdConfigInitDefaults() {
  local config_file
  config_file="$tmpdir/config.json"

  runCliWithConfig "$config_file" config init

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'Created config file'
  assertStderrNull

  assertNull "$(config_read_tags "$config_file")"
  assertNull "$(config_read_role "$config_file")"
  assertNull "$(config_read_skip_steps "$config_file")"
  assertNull "$(config_read_custom_add "$config_file")"
  assertNull "$(config_read_custom_remove "$config_file")"
}

testCmdConfigInitWithTags() {
  local config_file
  config_file="$tmpdir/config.json"

  runCliWithConfig "$config_file" config init --tags=alfa,bravo,charlie

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'Created config file'
  assertStderrNull

  assertContains "$(config_read_tags "$config_file")" alfa
  assertContains "$(config_read_tags "$config_file")" bravo
  assertContains "$(config_read_tags "$config_file")" charlie
  assertNull "$(config_read_role "$config_file")"
  assertNull "$(config_read_skip_steps "$config_file")"
  assertNull "$(config_read_custom_add "$config_file")"
  assertNull "$(config_read_custom_remove "$config_file")"
}

testCmdConfigInitWithFqdnShortFlag() {
  local config_file
  config_file="$tmpdir/config.json"

  runCliWithConfig "$config_file" config init -f mybox.example.com

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'Created config file'
  assertStderrNull

  assertEquals "mybox.example.com" "$(config_read_fqdn "$config_file")"
}

testCmdConfigInitWithFqdnLongFlag() {
  local config_file
  config_file="$tmpdir/config.json"

  runCliWithConfig "$config_file" config init --fqdn=anvil.local

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'Created config file'
  assertStderrNull

  assertEquals "anvil.local" "$(config_read_fqdn "$config_file")"
}

testCmdConfigInitFqdnAppendsLocalWhenNoDot() {
  local config_file
  config_file="$tmpdir/config.json"

  runCliWithConfig "$config_file" config init -f mybox

  assertTrue 'cli command failed' "$return_status"
  assertStderrNull

  assertEquals "mybox.local" "$(config_read_fqdn "$config_file")"
}

testCmdConfigInitFqdnPassesThroughWhenHasDot() {
  local config_file
  config_file="$tmpdir/config.json"

  runCliWithConfig "$config_file" config init -f mybox.corp.example.com

  assertTrue 'cli command failed' "$return_status"
  assertStderrNull

  assertEquals "mybox.corp.example.com" "$(config_read_fqdn "$config_file")"
}

testCmdConfigInitWithoutFqdnHasNoFqdnKey() {
  local config_file
  config_file="$tmpdir/config.json"

  runCliWithConfig "$config_file" config init

  assertTrue 'cli command failed' "$return_status"
  assertStderrNull

  assertNull "$(config_read_fqdn "$config_file")"
}

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
