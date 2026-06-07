#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
  . "$SRC_ROOT/lib/anvil/config.sh"
  . "$SRC_ROOT/lib/anvil/modules.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/phases/prepare.sh}"

  config_file="$(config_path)"
  data_home="$(modules_data_home)"

  unset __ANVIL_SUDO__
}

testDetectPrivilegeSetsEmptyWhenRoot() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # Stub id to return 0 (root)
  # shellcheck disable=SC2329
  id() { echo "0"; }

  run prepare_step_detect_privilege \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ANVIL_SUDO not empty' "" "${__ANVIL_SUDO__:-}"
}

testDetectPrivilegeSetsDoasOnOpenBSD() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # Stub id to return a non-root user uid
  # shellcheck disable=SC2329
  id() { echo "1000"; }
  # Stub uname for desired kernel
  # shellcheck disable=SC2329
  uname() { echo "OpenBSD"; }
  # Stub need_cmd to succeed without checking real commands
  # shellcheck disable=SC2329
  need_cmd() { :; }

  run prepare_step_detect_privilege \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ANVIL_SUDO not doas' "doas" "${__ANVIL_SUDO__:-}"
}

testDetectPrivilegeSetsSudoOnLinux() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # Stub id to return a non-root user uid
  # shellcheck disable=SC2329
  id() { echo "1000"; }
  # Stub uname for desired kernel
  # shellcheck disable=SC2329
  uname() { echo "Linux"; }
  # Stub need_cmd to succeed without checking real commands
  # shellcheck disable=SC2329
  need_cmd() { :; }

  run prepare_step_detect_privilege \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ANVIL_SUDO not sudo' "sudo" "${__ANVIL_SUDO__:-}"
}

testDetectPrivilegesLogsAndKeepsDisabledSentinelValue() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  __ANVIL_SUDO__="__disabled__"

  # If detect_sudo is invoked this will fail the test
  # shellcheck disable=SC2329
  detect_sudo() { return 1; }

  run prepare_step_detect_privilege \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'sentinel was overwritten' "__disabled__" "${__ANVIL_SUDO__:-}"
  assertStdoutContains 'Privilege elevation disabled'
}

testAcquireSudoFastPathWhenRoot() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # Simulate root user detected
  __ANVIL_SUDO__=""

  # If get_sudo or keep_sudo are called this will fail the test
  # shellcheck disable=SC2329
  get_sudo() { return 1; }
  # shellcheck disable=SC2329
  keep_sudo() { return 1; }

  run prepare_step_acquire_sudo \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed for root' "$return_status"
}

testAcquireSudoFastPathWhenDisabled() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  __ANVIL_SUDO__="__disabled__"

  # If get_sudo or keep_sudo are called this will fail the test
  # shellcheck disable=SC2329
  get_sudo() { return 1; }
  # shellcheck disable=SC2329
  keep_sudo() { return 1; }

  run prepare_step_acquire_sudo \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed when elevation is disabled' "$return_status"
  assertStdoutContains 'Privilege elevation disabled'
}

testAcquireSudoCallsGetAndKeepForNonRoot() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  __ANVIL_SUDO__="sudo"

  # Mock out get_sudo and keep_sudo
  _get_sudo_called=""
  # shellcheck disable=SC2329
  get_sudo() { _get_sudo_called="yes"; }
  _keep_sudo_called=""
  # shellcheck disable=SC2329
  keep_sudo() { _keep_sudo_called="yes"; }

  run prepare_step_acquire_sudo \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'get_sudo not called' "yes" "$_get_sudo_called"
  assertEquals 'keep_sudo not called' "yes" "$_keep_sudo_called"
}

testPrepareStepHostnameNoopWhenNoFqdn() {
  local hostname="current-host"
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  writeConfigFile '{}'

  run prepare_step_hostname \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testPrepareStepHostnameNoopWhenFqdnMatchesCurrent() {
  local hostname="host.local"
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  writeConfigFile '{"fqdn": "host.local"}'

  # Override facts_hostname to return the configured fqdn
  # shellcheck disable=SC2329
  facts_hostname() { echo "host.local"; }

  run prepare_step_hostname \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testPrepareStepsOrderIsCorrect() {
  local hostname="host.local"
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  run prepare_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  local output
  output="$(cat "$stdout")"
  local detect_pos acquire_pos hostname_pos
  detect_pos="$(echo "$output" | grep -n "detect_privilege" | cut -d: -f1)"
  acquire_pos="$(echo "$output" | grep -n "acquire_sudo" | cut -d: -f1)"
  hostname_pos="$(echo "$output" | grep -n "hostname" | cut -d: -f1)"

  assertTrue 'detect before acquire' "[ $detect_pos -lt $acquire_pos ]"
  assertTrue 'acquire before hostname' "[ $acquire_pos -lt $hostname_pos ]"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
