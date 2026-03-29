#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
  . "$SRC_ROOT/lib/anvil/hooks.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/phases/finalize.sh}"
}

# Helper: writes a config with the given tags
_writeConfigWithTags() {
  local config_file="$1"
  local tags_csv="$2"

  cat <<-EOF >"$config_file"
	{"tags": [$(echo "$tags_csv" | sed 's/,/","/g;s/^/"/;s/$/"/')]}
	EOF
}

# Helper: writes a tag JSON declaring a finalize hook for all os/arch
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
	      "all": { "all": ["${hook_name}"] }
	    }
	  }
	}
	EOF
}

testFinalizeStepsAlwaysContainsRecordRunAndCleanup() {
  run finalize_steps "$tmpdir" "/dev/null" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "record_run"
  assertStdoutContains "cleanup"
}

testFinalizeStepsEmitsNoHookStepsWhenNoTagsDeclareHooks() {
  run finalize_steps "$tmpdir" "/dev/null" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected' \
    "grep -q '^hook_' '$stdout'"
}

testFinalizeStepsHookStepAppearsBeforeRecordRun() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"
  _writeTagWithFinalizeHook "svc" "tailscaled"

  local config_file="$tmpdir/config.json"
  _writeConfigWithTags "$config_file" "svc"

  run finalize_steps "$tmpdir" "$config_file" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"

  local hook_line record_run_line
  hook_line="$(grep -n '^hook_tailscaled$' "$stdout" | cut -d: -f1)"
  record_run_line="$(grep -n '^record_run$' "$stdout" | cut -d: -f1)"

  assertTrue 'hook_tailscaled not found' "[ -n '$hook_line' ]"
  assertTrue 'hook must appear before record_run' \
    "[ '$hook_line' -lt '$record_run_line' ]"
}

testFinalizeStepsHookStepsInNumericOrderBeforeRecordRun() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/020-syncthing.sh"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"

  mkdir -p "$tmpdir/data/tags"

  cat <<-EOF >"$tmpdir/data/tags/svc.json"
	{
	  "name": "svc",
	  "depends_on": [],
	  "hooks": {
	    "finalize": {
	      "all": { "all": ["tailscaled", "syncthing"] }
	    }
	  }
	}
	EOF

  local config_file="$tmpdir/config.json"
  _writeConfigWithTags "$config_file" "svc"

  run finalize_steps "$tmpdir" "$config_file" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"

  local steps
  steps="$(cat "$stdout")"

  assertEquals 'wrong step order' \
    "$(printf 'hook_tailscaled\nhook_syncthing\nrecord_run\ncleanup')" \
    "$steps"
}

testFinalizeStepsDoesNotEmitHookWhenOsDoesNotMatch() {
  mkdir -p "$tmpdir/data/hooks/finalize"
  touch "$tmpdir/data/hooks/finalize/010-tailscaled.sh"

  mkdir -p "$tmpdir/data/tags"

  cat <<-EOF >"$tmpdir/data/tags/svc.json"
	{
	  "name": "svc",
	  "depends_on": [],
	  "hooks": {
	    "finalize": {
	      "arch": { "all": ["tailscaled"] }
	    }
	  }
	}
	EOF

  local config_file="$tmpdir/config.json"
  _writeConfigWithTags "$config_file" "svc"

  run finalize_steps "$tmpdir" "$config_file" "macos" "" "darwin" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected for non-matching os' \
    "grep -q '^hook_' '$stdout'"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
