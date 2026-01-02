#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../vendor/lib/libsh.full.sh"
  . "${SRC:=lib/anvil/convergence.sh}"

  commonOneTimeSetUp
}

setUp() {
  commonSetUp
}

testCalculatePackagesToInstall() {
  # Desired: git, vim, curl
  # Installed: git, curl,
  # Expected: vim

  local desired="git
vim
curl"

  local installed="git
curl"

  run convergence_delta "$desired" "$installed"

  assertTrue "convergence_delta failed" "$return_status"
  assertStdoutContains "vim"

  # Should not include git or curl
  assertFalse 'Should not include already installed packages' \
    "cat '$stdout' | grep -q '^git$'"
  assertFalse 'Should not include already installed packages' \
    "cat '$stdout' | grep -q '^curl$'"
}

shell_compat "$0"

. "$shunit2"
