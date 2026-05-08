#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  commonOneTimeSetUp

  . "${0%/*}/../vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/logging.sh}"

  unset __ANVIL_LOGGING__
}

makeFakeDate() {
  mkdir -p "$isolated_path"
  printf '#!/bin/sh\necho "2026-02-01T12-01-02Z"\n' >"$isolated_path/date"
  chmod +x "$isolated_path/date"

  PATH="$isolated_path:$PATH"
}

testLogDirRespectsXdgStateHome() {
  XDG_STATE_HOME="$tmpdir/state"

  run _logging_path

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "$XDG_STATE_HOME/anvil/logs"
  assertStderrNull
}

testLogDirFallsBackToHomeLocalState() {
  run _logging_path

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "$HOME/.local/state/anvil/logs"
  assertStderrNull
}

testLogFileHasCorrectFormat() {
  XDG_STATE_HOME="$tmpdir/state"

  makeFakeDate

  run _logging_file "anvil-apply"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals \
    "$XDG_STATE_HOME/anvil/logs/anvil-apply-2026-02-01T12-01-02Z.log"
  assertStderrNull
}

testLoggingExecReturnsEarlyWhenAlreadyLogging() {
  __ANVIL_LOGGING__=1

  run logging_exec "$root" "anvil-apply" "$root/bin/anvil" apply

  assertTrue 'function should succeed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../tmp/shunit2/shunit2"
