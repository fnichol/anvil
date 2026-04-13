#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
  . "$SRC_ROOT/lib/anvil/hooks.sh"
  . "$SRC_ROOT/lib/anvil/config.sh"
  . "$SRC_ROOT/lib/anvil/modules.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/phases/finalize.sh}"

  config_file="$(config_path)"
  data_home="$(modules_data_home)"
  mod_path="$(module_path_for "$data_home" default)"
}

# Helper: writes a config with the given tags
_writeConfigWithTags() {
  local tags_csv="$1"

  writeConfigFile <<-EOF
	{
	  "modules":[
	    {"name":"default","url":"https://example.com/default.git"}
	  ],
	  "tags": [$(echo "$tags_csv" | sed 's/,/","/g;s/^/"/;s/$/"/')]
	}
	EOF
}

# Helper: writes a tag JSON declaring a finalize hook for all os/arch
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
	      "all": { "all": ["${hook_name}"] }
	    }
	  }
	}
	EOF
}

testFinalizeStepsAlwaysContainsRecordRunAndCleanup() {
  run finalize_steps \
    "$config_file" "$data_home" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "record_run"
}

testFinalizeStepsEmitsNoHookStepsWhenNoTagsDeclareHooks() {
  run finalize_steps \
    "$config_file" "$data_home" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected' \
    "grep -q '^hook_' '$stdout'"
}

testFinalizeStepsHookStepAppearsBeforeRecordRun() {
  mkdir -p "$mod_path/hooks/finalize"
  touch "$mod_path/hooks/finalize/010-tailscaled.sh"
  _writeTagWithFinalizeHook "$mod_path" "svc" "tailscaled"

  _writeConfigWithTags "svc"

  run finalize_steps \
    "$config_file" "$data_home" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"

  local hook_line record_run_line
  hook_line="$(grep -n '^hook_tailscaled$' "$stdout" | cut -d: -f1)"
  record_run_line="$(grep -n '^record_run$' "$stdout" | cut -d: -f1)"

  assertTrue 'hook_tailscaled not found' "[ -n '$hook_line' ]"
  assertTrue 'hook must appear before record_run' \
    "[ '$hook_line' -lt '$record_run_line' ]"
}

testFinalizeStepsHookStepsInNumericOrderBeforeRecordRun() {
  mkdir -p "$mod_path/hooks/finalize"
  touch "$mod_path/hooks/finalize/020-syncthing.sh"
  touch "$mod_path/hooks/finalize/010-tailscaled.sh"

  mkdir -p "$mod_path/tags"
  cat <<-EOF >"$mod_path/tags/svc.json"
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

  _writeConfigWithTags "svc"

  run finalize_steps \
    "$config_file" "$data_home" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"

  local steps
  steps="$(cat "$stdout")"

  assertEquals 'wrong step order' \
    "$(printf 'hook_tailscaled\nhook_syncthing\nrecord_run')" \
    "$steps"
}

testFinalizeStepsDoesNotEmitHookWhenOsDoesNotMatch() {
  mkdir -p "$mod_path/hooks/finalize"
  touch "$mod_path/hooks/finalize/010-tailscaled.sh"

  mkdir -p "$mod_path/tags"
  cat <<-EOF >"$mod_path/tags/svc.json"
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

  _writeConfigWithTags "svc"

  run finalize_steps \
    "$config_file" "$data_home" "macos" "" "darwin" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected for non-matching os' \
    "grep -q '^hook_' '$stdout'"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
