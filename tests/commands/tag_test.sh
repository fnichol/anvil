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

testCmdTagNoArgsShowsHlep() {
  runCli tag

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'tag'
  assertStderrNull
}

testCmdTagHelpShortFlag() {
  runCli tag -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'tag'
  assertStderrNull
}

testCmdTagHelpLongFlag() {
  runCli tag --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'tag'
  assertStderrNull
}

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
