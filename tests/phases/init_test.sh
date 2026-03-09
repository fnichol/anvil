#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../../vendor/lib/libsh.full.sh"
  . "${SRC:=lib/anvil/phases/init.sh}"

  commonOneTimeSetUp
  root="${0%/*}/../.."
}

setUp() {
  commonSetUp
  unset __ANVIL_SUDO__
}

testDetectPrivilegeSetsEmptyWhenRoot() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  # Stub id to return 0 (root)
  id() { echo "0"; }

  run init_step_detect_privilege \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ANVIL_SUDO not empty' "" "${__ANVIL_SUDO__:-}"
}

testDetectPrivilegeSetsDoasOnOpenBSD() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  # Stub id to return a non-root user uid
  id() { echo "1000"; }
  # Stub uname for desired kernel
  uname() { echo "OpenBSD"; }
  # Stub need_cmd to succeed without checking real commands
  need_cmd() { :; }

  run init_step_detect_privilege \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ANVIL_SUDO not doas' "doas" "${__ANVIL_SUDO__:-}"
}

testDetectPrivilegeSetsSudoOnLinux() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  # Stub id to return a non-root user uid
  id() { echo "1000"; }
  # Stub uname for desired kernel
  uname() { echo "Linux"; }
  # Stub need_cmd to succeed without checking real commands
  need_cmd() { :; }

  run init_step_detect_privilege \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ANVIL_SUDO not sudo' "sudo" "${__ANVIL_SUDO__:-}"
}

testAcquireSudoFastPathWhenRoot() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  # Simulate root user detected
  __ANVIL_SUDO__=""

  # If get_sudo or keep_sudo are called this will fail the test
  get_sudo() { return 1; }
  keep_sudo() { return 1; }

  run init_step_acquire_sudo \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed for root' "$return_status"
}

testAcquireSudoCallsGetAndKeepForNonRoot() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  __ANVIL_SUDO__="sudo"

  # shellcheck source=lib/anvil/sudo.sh
  . "$root/lib/anvil/sudo.sh"

  # Mock out get_sudo and keep_sudo
  _get_sudo_called=""
  get_sudo() { _get_sudo_called="yes"; }
  _keep_sudo_called=""
  keep_sudo() { _keep_sudo_called="yes"; }

  run init_step_acquire_sudo \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'get_sudo not called' "yes" "$_get_sudo_called"
  assertEquals 'keep_sudo not called' "yes" "$_keep_sudo_called"
}

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
