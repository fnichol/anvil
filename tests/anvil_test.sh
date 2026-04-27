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

  . "${SRC:=lib/anvil/anvil.sh}"
}

testInstallsPathDefaultsToXdgDataHome() {
  unset XDG_DATA_HOME

  run anvil_installs_path

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "$HOME/.local/share/anvil/installs"
  assertStderrNull
}

testInstallsPathRespectsXdgDataHome() {
  export XDG_DATA_HOME="$tmpdir/data"

  run anvil_installs_path

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "$XDG_DATA_HOME/anvil/installs"
  assertStderrNull
}

testVersionLtReturnsTrueWhenPatchOlder() {
  assertTrue '0.1.0 < 0.1.1' "anvil_version_lt 0.1.0 0.1.1"
}

testVersionLtReturnsTrueWhenMinorOlder() {
  assertTrue '0.1.0 < 0.2.0' "anvil_version_lt 0.1.0 0.2.0"
}

testVersionLtReturnsTrueWhenMajorOlder() {
  assertTrue '0.9.9 < 1.0.0' "anvil_version_lt 0.9.9 1.0.0"
}

testVersionLtReturnsFalseWhenEqual() {
  assertFalse '0.1.0 !< 0.1.0' "anvil_version_lt 0.1.0 0.1.0"
}

testVersionLtReturnsFalseWhenNewer() {
  assertFalse '0.2.0 !< 0.1.0' "anvil_version_lt 0.2.0 0.1.0"
}

testLatestAnvilVersionParsesTagName() {
  # shellcheck disable=SC2329
  download() {
    printf '{"tag_name":"v0.2.0","name":"Anvil 0.2.0"}' >"$2"
  }

  run latest_anvil_version

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals '0.2.0'
  assertStderrNull
}

testLatestAnvilVersionReturnsEmptyOnDownloadFailure() {
  # shellcheck disable=SC2329
  download() {
    return 1
  }

  run latest_anvil_version

  assertTrue 'function should not fail' "$return_status"
  assertStdoutEquals ''
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../$shunit2RelRoot"
