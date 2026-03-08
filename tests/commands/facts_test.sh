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

testCmdFactsHelpShortFlag() {
  runCli facts -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'facts'
  assertStderrNull
}

testCmdFactsHelpLongFlag() {
  runCli facts --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'facts'
  assertStderrNull
}

testCmdConfigShowWithConfig() {
  runCli facts

  output="$tmpdir/output.txt"
  cat "$stdout" | stripAnsi >"$output"

  assertTrue 'cli command failed' "$return_status"
  assertJsonFromFile "$output" 'has("os")'
  assertJsonFromFile "$output" 'has("arch")'
  assertJsonFromFile "$output" 'has("kernel")'
  assertJsonFromFile "$output" 'has("version")'
  assertJsonFromFile "$output" 'has("hostname")'
  assertStderrNull
}

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
