#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/hooks.sh}"

  data_home="$(modules_data_home)"

  writeModuleFixture "default"
  writeConfigFile \
    '{"modules":[{"name":"default","url":"https://example.com/a.git"}]}'

  mod_path="$(module_path_for "$data_home" default)"
}

# Helper: writes a minimal tag JSON declaring a finalize hook
_writeTagWithFinalizeHook() {
  local mod_path="$1"
  local tag_name="$2"
  local hook_name="$3"

  mkdir -p "$mod_path/tags"

  cat <<-EOF >"$mod_path/tags/${tag_name}.json"
	{
	  "name": "${tag_name}",
	  "depends_on": [],
	  "hooks": {
	    "finalize": {
	      "arch": { "all": ["${hook_name}"] }
	    }
	  }
	}
	EOF
}

_writeTagWithAllOsHook() {
  local mod_path="$1"
  local tag_name="$2"
  local phase="$3"
  local hook_name="$4"

  mkdir -p "$mod_path/tags"

  cat <<-EOF >"$mod_path/tags/${tag_name}.json"
	{
	  "name": "${tag_name}",
	  "depends_on": [],
	  "hooks": {
	    "${phase}": {
	      "all": { "all": ["${hook_name}"] }
	    }
	  }
	}
	EOF
}

testHooksScriptForStepReturnsPathForMatchingName() {
  local hook_file
  hook_file="$mod_path/hooks/finalize/010-tailscaled.sh"

  mkdir -p "$(dirname "$hook_file")"
  touch "$hook_file"

  run hooks_script_for_step \
    "$(config_path)" \
    "$data_home" \
    "finalize" \
    "tailscaled"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "010-tailscaled.sh"
}

testHooksScriptForStepFailsWhenNameNotFound() {
  local hook_path
  hook_path="$mod_path/hooks/finalize"
  mkdir -p "$hook_path"

  run hooks_script_for_step \
    "$(config_path)" \
    "$data_home" \
    "finalize" \
    "nonexistent"

  assertFalse 'function should have failed' "$return_status"
}

testHooksScriptForStepMatchesHyphenatedFilenameByUnderscoredName() {
  local hook_file
  hook_file="$mod_path/hooks/configure/010-ssh-keys.sh"

  mkdir -p "$(dirname "$hook_file")"
  touch "$hook_file"

  run hooks_script_for_step \
    "$(config_path)" \
    "$data_home" \
    "configure" \
    "ssh_keys"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "010-ssh-keys.sh"
}

testHooksScriptForNameReturnsPathForMatchingName() {
  local hook_file
  hook_file="$mod_path/hooks/finalize/010-tailscaled-service.sh"

  mkdir -p "$(dirname "$hook_file")"
  touch "$hook_file"

  run hooks_script_for_name \
    "$(config_path)" \
    "$data_home" \
    "finalize" \
    "tailscaled-service"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "010-tailscaled-service.sh"
}

testHooksScriptForNameFailsWhenNameNotFound() {
  local hook_path
  hook_path="$mod_path/hooks/finalize"
  mkdir -p "$hook_path"

  run hooks_script_for_name \
    "$(config_path)" \
    "$data_home" \
    "finalize" \
    "nonexistent"

  assertFalse 'function should have failed' "$return_status"
}

testHooksScriptForNameFailsWhenDirAbsent() {
  run hooks_script_for_name \
    "$(config_path)" \
    "$tmpdir/no-such-root" \
    "finalize" \
    "anything"

  assertFalse 'function should have failed' "$return_status"
}

testHooksScriptForNameMatchesAmongMultipleFiles() {
  local hook_path
  hook_path="$mod_path/hooks/finalize"

  mkdir -p "$hook_path"
  touch "$hook_path/010-tailscaled-service.sh"
  touch "$hook_path/020-syncthing.sh"

  run hooks_script_for_name \
    "$(config_path)" \
    "$data_home" \
    "finalize" \
    "syncthing"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "020-syncthing.sh"
}

testHooksStepsForPhaseEmitsNothingWithEmptyTags() {
  run hooks_steps_for_phase \
    "$(config_path)" \
    "$data_home" \
    "arch" \
    "x86_64" \
    "finalize" \
    ""

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
}

testHooksStepsForPhaseEmitsStepForDeclaredHook() {
  mkdir -p "$mod_path/hooks/finalize"
  touch "$mod_path/hooks/finalize/010-tailscaled.sh"
  _writeTagWithFinalizeHook "$mod_path" "svc" "tailscaled"

  run hooks_steps_for_phase \
    "$(config_path)" \
    "$data_home" \
    "arch" \
    "x86_64" \
    "finalize" \
    "svc"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "hook_tailscaled"
}

testHooksStepsForPhaseSkipsHookNotMatchingOs() {
  mkdir -p "$mod_path/hooks/finalize"
  touch "$mod_path/hooks/finalize/010-tailscaled.sh"
  _writeTagWithFinalizeHook "$mod_path" "svc" "tailscaled"

  # macos does not match arch-only declaration
  run hooks_steps_for_phase \
    "$(config_path)" \
    "$data_home" \
    "macos" \
    "x86_64" \
    "finalize" \
    "svc"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
}

testHooksStepsForPhaseRunsAllOsHookOnAnyPlatform() {
  mkdir -p "$mod_path/hooks/finalize"
  touch "$mod_path/hooks/finalize/010-common.sh"
  _writeTagWithAllOsHook "$mod_path" "base" "finalize" "common"

  run hooks_steps_for_phase \
    "$(config_path)" \
    "$data_home" \
    "macos" \
    "x86_64" \
    "finalize" \
    "base"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "hook_common"
}

testHooksStepsForPhaseSortsHooksByNumericPrefix() {
  mkdir -p "$mod_path/hooks/finalize"
  touch "$mod_path/hooks/finalize/020-syncthing.sh"
  touch "$mod_path/hooks/finalize/010-tailscaled.sh"
  _writeTagWithFinalizeHook "$mod_path" "svc" "tailscaled"

  # Add syncthing to same tag
  cat <<-EOF >"$mod_path/tags/svc.json"
	{
	  "name": "svc",
	  "depends_on": [],
	  "hooks": {
	    "finalize": {
	      "arch": { "all": ["tailscaled", "syncthing"] }
	    }
	  }
	}
	EOF

  run hooks_steps_for_phase \
    "$(config_path)" \
    "$data_home" \
    "arch" \
    "x86_64" \
    "finalize" \
    "svc"

  assertTrue 'function failed' "$return_status"
  assertEquals 'wrong order' \
    "$(printf 'hook_tailscaled\nhook_syncthing')" \
    "$(cat "$stdout")"
}

testHooksStepsForPhaseDeduplicatesAcrossTags() {
  mkdir -p "$mod_path/hooks/finalize"
  touch "$mod_path/hooks/finalize/010-tailscaled.sh"
  _writeTagWithAllOsHook "$mod_path" "tag-a" "finalize" "tailscaled"
  _writeTagWithAllOsHook "$mod_path" "tag-b" "finalize" "tailscaled"

  run hooks_steps_for_phase \
    "$(config_path)" \
    "$data_home" \
    "arch" \
    "x86_64" \
    "finalize" \
    "tag-a tag-b"

  assertTrue 'function failed' "$return_status"
  assertEquals 'expected exactly one step' \
    "hook_tailscaled" \
    "$(cat "$stdout")"
}

testHooksStepsForPhaseDiesWhenDeclaredHookFileMissing() {
  _writeTagWithFinalizeHook "$mod_path" "svc" "nonexistent"

  run hooks_steps_for_phase \
    "$(config_path)" \
    "$data_home" \
    "arch" \
    "x86_64" \
    "finalize" \
    "svc"

  assertFalse 'function should have failed' "$return_status"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../$shunit2RelRoot"
