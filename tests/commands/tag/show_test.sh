#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../../_ksh_local.sh"

oneTimeSetUp() {
  commonOneTimeSetUp
  root="${0%/*}/../../.."
}

setUp() {
  commonSetUp
}

runCli() {
  run "$root/bin/anvil" "$@"
}

testCmdTagShowHelpShortFlag() {
  runCli tag show -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'tag show'
  assertStderrNull
}

testCmdTagShowHelpLongFlag() {
  runCli tag show --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'tag show'
  assertStderrNull
}

testCmdTagShowNoNameFails() {
  runCli tag show

  assertFalse 'cli command succeeded' "$return_status"
  assertStdoutNull
  assertStderrContains 'USAGE:'
  assertStderrContains 'tag show'
  assertStderrContains 'required argument: NAME'
}

testCmdTagShowWithName() {
  runCli tag show base

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'Tag: base'
  assertStderrNull
}

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
