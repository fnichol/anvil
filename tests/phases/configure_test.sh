#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
  . "$SRC_ROOT/lib/anvil/hooks.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/phases/configure.sh}"
}

testConfigureStepsEmitsNoHookStepsWhenDirAbsent() {
  run configure_steps "$tmpdir" "/dev/null" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected' \
    "grep -q '^hook_' '$stdout'"
}

testConfigureStepsEmitsHookStepsWhenHooksExist() {
  mkdir -p "$tmpdir/data/hooks/configure"
  touch "$tmpdir/data/hooks/configure/010-ssh_keys.sh"

  run configure_steps "$tmpdir" "/dev/null" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "hook_ssh_keys"
}

testConfigureStepsEmitsMultipleHooksInNumericOrder() {
  mkdir -p "$tmpdir/data/hooks/configure"
  touch "$tmpdir/data/hooks/configure/020-gpg_keys.sh"
  touch "$tmpdir/data/hooks/configure/010-ssh_keys.sh"

  run configure_steps "$tmpdir" "/dev/null" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertEquals 'wrong order' \
    "$(printf 'hook_ssh_keys\nhook_gpg_keys')" \
    "$(grep '^hook_' "$stdout")"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
