#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/sudo.sh}"

  unset __ANVIL_SUDO__
}

makeFakeSudo() {
  # Create a fake sudo that records its invocation
  mkdir -p "$isolated_path"
  local fakesudo="$isolated_path/sudo"
  printf '#!/bin/sh\necho "sudo:$*"\n' >"$fakesudo"
  chmod 755 "$fakesudo"
  PATH="$isolated_path:$PATH"

  __ANVIL_SUDO__="$fakesudo"
}

makeFakeDoas() {
  # Create a fake doas that records its invocation
  mkdir -p "$isolated_path"
  local fakedoas="$isolated_path/doas"
  printf '#!/bin/sh\necho "doas:$*"\n' >"$fakedoas"
  chmod +x "$fakedoas"
  PATH="$isolated_path:$PATH"

  __ANVIL_SUDO__="$fakedoas"
}

testAsRootWhenRootRunsDirectly() {
  __ANVIL_SUDO__=""

  run as_root echo "hello-root"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "hello-root"
  assertStderrNull
}

testRunAsRootWithSudoPrependsSudo() {
  makeFakeSudo

  run as_root echo "hello"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "sudo:echo hello"
  assertStderrNull
}

testRunAsRootWithDoasPrependsDoas() {
  makeFakeDoas

  run as_root echo "hello"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "doas:echo hello"
  assertStderrNull
}

testGetSudoCallsSudoV() {
  makeFakeSudo

  run get_sudo "bacon.local"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals \
    "sudo:-v -p [sudo required for some tasks] Password for %u@bacon.local: "
  assertStderrNull
}

testGetSudoCallsDoasTrue() {
  makeFakeDoas

  run get_sudo "bacon.local"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "doas:true"
  assertStderrNull
}

testKeepSudoSpawnsBackgroundJobAndReturns() {
  mkdir -p "$isolated_path"
  # Fake sudo that sleeps forever — verifies keep_sudo doesn't block
  # shellcheck disable=SC2016
  printf '#!/bin/sh\ncase "$1" in -n) sleep 9999 ;; esac\n' \
    >"$isolated_path/sudo"
  chmod +x "$isolated_path/sudo"
  PATH="$isolated_path:$PATH"

  __ANVIL_SUDO__="sudo"

  # keep_sudo must return (not block) — if it hangs this test hangs too
  run keep_sudo

  assertTrue 'keep_sudo failed' "$return_status"
  # Clean up the background job
  kill %1 2>/dev/null || true
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../tmp/shunit2/shunit2"
