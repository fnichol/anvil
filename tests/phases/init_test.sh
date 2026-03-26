#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/phases/init.sh}"

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
  # shellcheck disable=SC2329
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
  # shellcheck disable=SC2329
  id() { echo "1000"; }
  # Stub uname for desired kernel
  # shellcheck disable=SC2329
  uname() { echo "OpenBSD"; }
  # Stub need_cmd to succeed without checking real commands
  # shellcheck disable=SC2329
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
  # shellcheck disable=SC2329
  id() { echo "1000"; }
  # Stub uname for desired kernel
  # shellcheck disable=SC2329
  uname() { echo "Linux"; }
  # Stub need_cmd to succeed without checking real commands
  # shellcheck disable=SC2329
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
  # shellcheck disable=SC2329
  get_sudo() { return 1; }
  # shellcheck disable=SC2329
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

  # Mock out get_sudo and keep_sudo
  _get_sudo_called=""
  # shellcheck disable=SC2329
  get_sudo() { _get_sudo_called="yes"; }
  _keep_sudo_called=""
  # shellcheck disable=SC2329
  keep_sudo() { _keep_sudo_called="yes"; }

  run init_step_acquire_sudo \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'get_sudo not called' "yes" "$_get_sudo_called"
  assertEquals 'keep_sudo not called' "yes" "$_keep_sudo_called"
}

testValidateCommandsSucceedsWhenAllCommandsPresent() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  # Stub check_cmd to always find commands (curl present)
  # shellcheck disable=SC2329
  check_cmd() { return 0; }
  # Stub need_cmd to succeed without checking real commands
  # shellcheck disable=SC2329
  need_cmd() { :; }

  run init_step_validate_commands \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStderrNull
}

testValidateCommandsFailsWhenNeitherCurlNorWget() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  # Neither curl nor wget present
  # shellcheck disable=SC2329
  check_cmd() { return 1; }
  # shellcheck disable=SC2329
  uname() { echo "Linux"; }
  # shellcheck disable=SC2329
  need_cmd() { :; }

  run init_step_validate_commands \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertFalse 'should have failed without curl/wget' "$return_status"
}

testValidateCommandsAcceptsWgetWhenNoCurl() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  # Only wget present
  # shellcheck disable=SC2329
  check_cmd() {
    case "$1" in
      wget) return 0 ;;
      *) return 1 ;;
    esac
  }
  # shellcheck disable=SC2329
  uname() { echo "Linux"; }
  # shellcheck disable=SC2329
  need_cmd() { :; }

  run init_step_validate_commands \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed with wget' "$return_status"
}

testValidateCommandsAcceptsForOpenBSDWhenNeitherCurlNorWgetButFtp() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  # Only wget present
  # shellcheck disable=SC2329
  check_cmd() {
    case "$1" in
      ftp) return 0 ;;
      *) return 1 ;;
    esac
  }
  # Stub uname for desired kernel
  # shellcheck disable=SC2329
  uname() { echo "OpenBSD"; }
  # shellcheck disable=SC2329
  need_cmd() { :; }

  run init_step_validate_commands \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should suceed with ftp' "$return_status"
}

testValidateCommandsFailsForOpenBSDWhenNeitherCurlWgetNorFtp() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  # Neither curl nor wget nor ftp present
  # shellcheck disable=SC2329
  check_cmd() { return 1; }
  # shellcheck disable=SC2329
  uname() { echo "OpenBSD"; }
  # shellcheck disable=SC2329
  need_cmd() { :; }

  run init_step_validate_commands \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertFalse 'should have failed without curl/wget/ftp' "$return_status"
}

testEnsureToolsCallsEnsureJq() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  _ensure_jq_called=""
  # shellcheck disable=SC2329
  ensure_jq() { _ensure_jq_called="yes"; }

  run init_step_ensure_tools \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ensure_jq was not called' "yes" "$_ensure_jq_called"
  assertStderrNull
}

testInitStepsIncludesEnsureTools() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  run init_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "ensure_tools"
}

testInitStepsOrderIsCorrect() {
  local config_path="$tmpdir/nonexistent.json"
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  run init_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  local output
  output="$(cat "$stdout")"
  local validate_pos detect_pos acquire_pos ensure_pos
  validate_pos="$(echo "$output" | grep -n "validate_commands" | cut -d: -f1)"
  detect_pos="$(echo "$output" | grep -n "detect_privilege" | cut -d: -f1)"
  acquire_pos="$(echo "$output" | grep -n "acquire_sudo" | cut -d: -f1)"
  ensure_pos="$(echo "$output" | grep -n "ensure_tools" | cut -d: -f1)"

  assertTrue 'validate before detect' "[ $validate_pos -lt $detect_pos ]"
  assertTrue 'detect before acquire' "[ $detect_pos -lt $acquire_pos ]"
  assertTrue 'acquire before ensure' "[ $acquire_pos -lt $ensure_pos ]"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
