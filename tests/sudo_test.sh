#!/usr/bin/env sh
# shellcheck disable=SC3043

# shuck: source=_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  commonOneTimeSetUp

  # shuck: source=../vendor/lib/libsh.full.sh
  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  # shuck: source=../lib/anvil/sudo.sh
  . "${SRC:=lib/anvil/sudo.sh}"

  unset __ANVIL_SUDO__

  ANVIL_ROOT="$SRC_ROOT"
  export ANVIL_ROOT
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

testAsRootDiesWhenElevationIsDisabled() {
  run_in_sh_script <<-'EOF'
	. "$ANVIL_ROOT/vendor/lib/libsh.full.sh"
	__ANVIL_SUDO__="__disabled__"
	as_root echo "hello"
	EOF

  assertFalse 'as_root should refuse when elevation is disabled' "$return_status"
  assertStdoutNull
  assertStderrContains 'Privilege elevation disabled'
  assertStderrContains 'refusing to run: echo hello'
}

testDetectSudoPreservesDisabledSentinelValue() {
  __ANVIL_SUDO__="__disabled__"

  # Stub id/uname/need_cmd — if detect_sudo probes despite the sentinel value,
  # let the function run to completion and overwrite __ANVIL_SUDO__

  # shellcheck disable=SC2329
  id() { echo "1000"; }
  # shellcheck disable=SC2329
  uname() { echo "Linux"; }
  # shellcheck disable=SC2329
  need_cmd() { :; }

  run detect_sudo

  assertTrue 'function failed' "$return_status"
  assertEquals 'sentinel was overwritten' "__disabled__" "${__ANVIL_SUDO__:-}"
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
  sudo_pid_file="$tmpdir/sudo.pid"
  # Fake sudo that sleeps forever — verifies keep_sudo doesn't block. It records
  # its pid (and `exec`s into the sleep, so that is the only process) so the
  # test can stop it: killing keep_sudo's background loop alone would leave this
  # fake and its sleep running after the test.
  # shellcheck disable=SC2016
  printf '#!/bin/sh\ncase "$1" in -n) echo $$ >"%s"; exec sleep 9999 ;; esac\n' \
    "$sudo_pid_file" >"$isolated_path/sudo"
  chmod +x "$isolated_path/sudo"
  PATH="$isolated_path:$PATH"

  __ANVIL_SUDO__="sudo"

  # keep_sudo must return (not block) — if it hangs this test hangs too
  run keep_sudo

  assertTrue 'keep_sudo failed' "$return_status"

  # Clean up the background loop, then the fake sudo it was waiting on (giving
  # the fake a moment to record its pid if it has not started yet)
  kill %1 2>/dev/null || true
  _tries=0
  while [ ! -s "$sudo_pid_file" ] && [ "$_tries" -lt 5 ]; do
    sleep 1
    _tries=$((_tries + 1))
  done
  if [ -s "$sudo_pid_file" ]; then
    kill "$(cat "$sudo_pid_file")" 2>/dev/null || true
  fi
}

# shuck: source=test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

# shuck: source=../vendor/lib/shunit2.sh
. "${0%/*}/../vendor/lib/shunit2.sh"
