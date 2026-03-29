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

  . "${SRC:=lib/anvil/phases/configure.sh}"
}

# Helper: writes a config with the given tags
_writeConfigWithTags() {
  local config_file="$1"
  local tags_csv="$2"

  cat <<-EOF >"$config_file"
	{"tags": [$(echo "$tags_csv" | sed 's/,/","/g;s/^/"/;s/$/"/')]}
	EOF
}

# Helper: writes a tag JSON declaring a configure hook for all os/arch
_writeTagWithConfigureHook() {
  local tag_name="$1"
  local hook_name="$2"

  mkdir -p "$tmpdir/data/tags"

  cat <<-EOF >"$tmpdir/data/tags/${tag_name}.json"
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
  run configure_steps "$tmpdir" "/dev/null" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected' \
    "grep -q '^hook_' '$stdout'"
}

testConfigureStepsEmitsHookStepWhenTagDeclaresIt() {
  mkdir -p "$tmpdir/data/hooks/configure"
  touch "$tmpdir/data/hooks/configure/010-ssh-key.sh"
  _writeTagWithConfigureHook "myconf" "ssh-key"

  local config_file="$tmpdir/config.json"
  _writeConfigWithTags "$config_file" "myconf"

  run configure_steps "$tmpdir" "$config_file" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "hook_ssh_key"
}

testConfigureStepsDoesNotEmitHookWhenOsDoesNotMatch() {
  mkdir -p "$tmpdir/data/hooks/configure"
  touch "$tmpdir/data/hooks/configure/010-ssh-key.sh"
  mkdir -p "$tmpdir/data/tags"

  cat <<-EOF >"$tmpdir/data/tags/myconf.json"
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

  local config_file="$tmpdir/config.json"
  _writeConfigWithTags "$config_file" "myconf"

  run configure_steps "$tmpdir" "$config_file" "macos" "" "darwin" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected for non-matching os' \
    "grep -q '^hook_' '$stdout'"
}

testConfigureStepsEmitsMultipleHooksInNumericOrder() {
  mkdir -p "$tmpdir/data/hooks/configure"
  touch "$tmpdir/data/hooks/configure/020-gpg-key.sh"
  touch "$tmpdir/data/hooks/configure/010-ssh-key.sh"

  mkdir -p "$tmpdir/data/tags"

  cat <<-EOF >"$tmpdir/data/tags/myconf.json"
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

  local config_file="$tmpdir/config.json"
  _writeConfigWithTags "$config_file" "myconf"

  run configure_steps "$tmpdir" "$config_file" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertEquals 'wrong order' \
    "$(printf 'hook_ssh_key\nhook_gpg_key')" \
    "$(grep '^hook_' "$stdout")"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
