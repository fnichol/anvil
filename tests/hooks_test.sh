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
}

# Helper: writes a minimal tag JSON declaring a finalize hook
_writeTagWithFinalizeHook() {
  local tag_name="$1"
  local hook_name="$2"

  mkdir -p "$tmpdir/data/tags"

  cat <<-EOF >"$tmpdir/data/tags/${tag_name}.json"
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
  local tag_name="$1"
  local phase="$2"
  local hook_name="$3"

  mkdir -p "$tmpdir/data/tags"

  cat <<-EOF >"$tmpdir/data/tags/${tag_name}.json"
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
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"

  run hooks_script_for_step "$tmpdir" "finalize" "tailscaled"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "010-tailscaled.sh"
}

testHooksScriptForStepFailsWhenNameNotFound() {
  mkdir -p "$tmpdir/data/hooks/finalize"

  run hooks_script_for_step "$tmpdir" "finalize" "nonexistent"

  assertFalse 'function should have failed' "$return_status"
}

testHooksScriptForStepMatchesHyphenatedFilenameByUnderscoredName() {
  mkdir -p "$tmpdir/data/hooks/configure"
  touch "$tmpdir/data/hooks/configure/010-ssh-keys.sh"

  run hooks_script_for_step "$tmpdir" "configure" "ssh_keys"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "010-ssh-keys.sh"
}

testHooksScriptForNameReturnsPathForMatchingName() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled-service.sh"

  run hooks_script_for_name "$tmpdir" "finalize" "tailscaled-service"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "010-tailscaled-service.sh"
}

testHooksScriptForNameFailsWhenNameNotFound() {
  mkdir -p "$tmpdir/data/hooks/finalize"

  run hooks_script_for_name "$tmpdir" "finalize" "nonexistent"

  assertFalse 'function should have failed' "$return_status"
}

testHooksScriptForNameFailsWhenDirAbsent() {
  run hooks_script_for_name "$tmpdir/no-such-root" "finalize" "anything"

  assertFalse 'function should have failed' "$return_status"
}

testHooksScriptForNameMatchesAmongMultipleFiles() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled-service.sh"
  touch "$tmpdir/data/hooks/finalize/020-syncthing.sh"

  run hooks_script_for_name "$tmpdir" "finalize" "syncthing"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "020-syncthing.sh"
}

testHooksStepsForPhaseEmitsNothingWithEmptyTags() {
  run hooks_steps_for_phase "$tmpdir" "arch" "x86_64" "finalize" ""

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
}

testHooksStepsForPhaseEmitsStepForDeclaredHook() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"
  _writeTagWithFinalizeHook "svc" "tailscaled"

  run hooks_steps_for_phase "$tmpdir" "arch" "x86_64" "finalize" "svc"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "hook_tailscaled"
}

testHooksStepsForPhaseSkipsHookNotMatchingOs() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"
  _writeTagWithFinalizeHook "svc" "tailscaled"

  # macos does not match arch-only declaration
  run hooks_steps_for_phase "$tmpdir" "macos" "x86_64" "finalize" "svc"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
}

testHooksStepsForPhaseRunsAllOsHookOnAnyPlatform() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-common.sh"
  _writeTagWithAllOsHook "base" "finalize" "common"

  run hooks_steps_for_phase "$tmpdir" "macos" "x86_64" "finalize" "base"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "hook_common"
}

testHooksStepsForPhaseSortsHooksByNumericPrefix() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/020-syncthing.sh"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"
  _writeTagWithFinalizeHook "svc" "tailscaled"

  # Add syncthing to same tag
  cat <<-EOF >"$tmpdir/data/tags/svc.json"
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

  run hooks_steps_for_phase "$tmpdir" "arch" "x86_64" "finalize" "svc"

  assertTrue 'function failed' "$return_status"
  assertEquals 'wrong order' \
    "$(printf 'hook_tailscaled\nhook_syncthing')" \
    "$(cat "$stdout")"
}

testHooksStepsForPhaseDeduplicatesAcrossTags() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"
  _writeTagWithAllOsHook "tag-a" "finalize" "tailscaled"
  _writeTagWithAllOsHook "tag-b" "finalize" "tailscaled"

  run hooks_steps_for_phase "$tmpdir" "arch" "x86_64" "finalize" "tag-a tag-b"

  assertTrue 'function failed' "$return_status"
  assertEquals 'expected exactly one step' \
    "hook_tailscaled" \
    "$(cat "$stdout")"
}

testHooksStepsForPhaseDiesWhenDeclaredHookFileMissing() {
  _writeTagWithFinalizeHook "svc" "nonexistent"

  run hooks_steps_for_phase "$tmpdir" "arch" "x86_64" "finalize" "svc"

  assertFalse 'function should have failed' "$return_status"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../$shunit2RelRoot"
