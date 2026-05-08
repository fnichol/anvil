#!/usr/bin/env sh

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

oneTimeSetUp() {
  commonOneTimeSetUp
}

setUp() {
  commonSetUp
}

testAnvilNoArgsShowsHelp() {
  run "$root/bin/anvil"

  assertTrue 'anvil succeeded with no args' "$return_status"
  assertStdoutContains 'System provisioning and configuration'
}

testAnvilHelpFlag() {
  run "$root/bin/anvil" --help

  assertTrue 'anvil --help failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'apply'
}

testAnvilVersion() {
  run "$root/bin/anvil" --version

  assertTrue 'anvil --version failed' "$return_status"
  assertStdoutContains 'anvil'
}

shell_compat "$0"

. "$shunit2"
