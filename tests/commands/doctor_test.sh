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

testCmdDoctorHelpShortFlag() {
  runCli doctor -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'doctor'
  assertStderrNull
}

testCmdDoctorHelpLongFlag() {
  runCli doctor --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'doctor'
  assertStderrNull
}

testCmdDoctor() {
  runCli doctor

  # NOTE: This command might exit non-zero if there are issues and may report
  # detail on stderr, so we aren't checking either of these

  assertStdoutContains 'Anvil Doctor'
  assertStdoutContains 'Required Commands'
  assertStdoutContains 'Platform-Specific'
  assertStdoutContains 'Configuration'
  assertStdoutContains 'Data Directory'
  assertStdoutContains 'Summary'
}

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
