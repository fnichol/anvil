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

  . "${SRC:=lib/anvil/phases/init.sh}"

  config_file="$(config_path)"
  data_home="$(modules_data_home)"
}

testValidateCommandsSucceedsWhenAllCommandsPresent() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStderrNull
}

testValidateCommandsFailsWhenNeitherCurlNorWget() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertFalse 'should have failed without curl/wget' "$return_status"
}

testValidateCommandsAcceptsWgetWhenNoCurl() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed with wget' "$return_status"
}

testValidateCommandsAcceptsForOpenBSDWhenNeitherCurlNorWgetButFtp() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should suceed with ftp' "$return_status"
}

testValidateCommandsFailsForOpenBSDWhenNeitherCurlWgetNorFtp() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertFalse 'should have failed without curl/wget/ftp' "$return_status"
}

testEnsureToolsCallsEnsureJq() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ensure_jq was not called' "yes" "$_ensure_jq_called"
  assertStderrNull
}

testInitStepsIncludesEnsureTools() {
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  run init_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "ensure_tools"
}

testInitStepsIncludesSanitizeEnvironment() {
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  run init_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "sanitize_environment"
}

testInitStepsOrderIsCorrect() {
  # Init phase doesn't have these values yet as it is run *before* facts phase
  local hostname=""
  local os=""
  local version=""
  local kernel=""
  local arch=""

  run init_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  local output
  output="$(cat "$stdout")"
  local sanitize_pos validate_pos ensure_pos
  sanitize_pos="$(
    echo "$output" | grep -n "sanitize_environment" | cut -d: -f1
  )"
  validate_pos="$(echo "$output" | grep -n "validate_commands" | cut -d: -f1)"
  ensure_pos="$(echo "$output" | grep -n "ensure_tools" | cut -d: -f1)"

  assertTrue 'sanitize before validate' "[ $sanitize_pos -lt $validate_pos ]"
  assertTrue 'validate before ensure' "[ $validate_pos -lt $ensure_pos ]"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
