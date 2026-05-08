#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../../.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "$SRC_ROOT/lib/anvil/config.sh"
}

runCli() {
  run "$root/bin/anvil" "$@"
}

runCliWithConfig() {
  local config_file="$1"
  shift

  ANVIL_CONFIG_PATH="$config_file" runCli "$@"
}

testCmdConfigShowHelpShortFlag() {
  runCli config show -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'config show'
  assertStderrNull
}

testCmdConfigShowHelpLongFlag() {
  runCli config show --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'config show'
  assertStderrNull
}

testCmdConfigShowWithConfig() {
  local config_file output
  config_file="$tmpdir/config.json"
  config_create "$config_file" "base,development"

  runCliWithConfig "$config_file" config show

  output="$tmpdir/show_output.txt"
  cat "$stdout" | stripAnsi >"$output"

  assertTrue 'cli command failed' "$return_status"
  assertJsonFromFile "$output" '.tags | length == 2'
  assertJsonFromFile "$output" '.tags | contains(["base"])'
  assertJsonFromFile "$output" '.tags | contains(["development"])'
  assertJsonFromFile "$output" '.skip_steps | length == 0'
  assertJsonFromFile "$output" '.custom_packages.add | length == 0'
  assertJsonFromFile "$output" '.custom_packages.remove | length == 0'
  assertStderrNull
}

testCmdConfigShowNoConfig() {
  local config_file
  config_file="$tmpdir/nonexistent.json"

  runCliWithConfig "$config_file" config show

  output="$tmpdir/show_output.txt"
  cat "$stdout" | stripAnsi >"$output"

  assertTrue 'cli command failed' "$return_status"
  assertJsonFromFile "$output" 'select(has("tags") | not)'
  assertJsonFromFile "$output" 'select(has("skip_steps") | not)'
  assertJsonFromFile "$output" 'select(has("custom_packages") | not)'
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
