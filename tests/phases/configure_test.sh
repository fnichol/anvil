#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
  . "$SRC_ROOT/lib/anvil/hooks.sh"
  . "$SRC_ROOT/lib/anvil/modules.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/phases/configure.sh}"

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

# Helper: writes a tag JSON declaring a configure hook for all os/arch
_writeTagWithConfigureHook() {
  local mod_path="$1"
  local tag_name="$2"
  local hook_name="$3"

  mkdir -p "$mod_path/tags"

  cat <<-EOF >"$mod_path/tags/${tag_name}.json"
	{
	  "name": "${tag_name}",
	  "depends_on": [],
	  "hooks": {
	    "configure": {
	      "all": { "all": ["${hook_name}"] }
	    }
	  }
	}
	EOF
}

testConfigureStepsEmitsNoHookStepsWhenNoTagsDeclareHooks() {
  writeConfigFile '{}'

  run configure_steps "$config_file" "$data_home" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected' \
    "grep -q '^hook_' '$stdout'"
}

testConfigureStepsEmitsHookStepWhenTagDeclaresIt() {
  mkdir -p "$mod_path/hooks/configure"
  touch "$mod_path/hooks/configure/010-ssh-key.sh"
  _writeTagWithConfigureHook "$mod_path" "myconf" "ssh-key"

  _writeConfigWithTags "myconf"

  run configure_steps "$config_file" "$data_home" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "hook_ssh_key"
}

testConfigureStepsDoesNotEmitHookWhenOsDoesNotMatch() {
  mkdir -p "$mod_path/hooks/configure"
  touch "$mod_path/hooks/configure/010-ssh-key.sh"
  mkdir -p "$mod_path/tags"

  cat <<-EOF >"$mod_path/tags/myconf.json"
	{
	  "name": "myconf",
	  "depends_on": [],
	  "hooks": {
	    "configure": {
	      "arch": { "all": ["ssh-key"] }
	    }
	  }
	}
	EOF

  _writeConfigWithTags "myconf"

  run configure_steps "$config_file" "$data_home" "macos" "" "darwin" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected for non-matching os' \
    "grep -q '^hook_' '$stdout'"
}

testConfigureStepsEmitsMultipleHooksInNumericOrder() {
  _writeConfigWithTags "myconf"
  writeModuleFixture "default"

  local configure_hooks_path
  configure_hooks_path="$mod_path/hooks/configure"
  mkdir -p "$configure_hooks_path"
  touch "$configure_hooks_path/020-gpg-key.sh"
  touch "$configure_hooks_path/010-ssh-key.sh"

  local tags_path
  tags_path="$mod_path/tags"
  mkdir -p "$tags_path"

  cat <<-EOF >"$tags_path/myconf.json"
	{
	  "name": "myconf",
	  "depends_on": [],
	  "hooks": {
	    "configure": {
	      "all": { "all": ["ssh-key", "gpg-key"] }
	    }
	  }
	}
	EOF

  run configure_steps "$config_file" "$data_home" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertEquals 'wrong order' \
    "$(printf 'hook_ssh_key\nhook_gpg_key')" \
    "$(grep '^hook_' "$stdout")"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
