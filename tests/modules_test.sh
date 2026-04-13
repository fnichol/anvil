#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/modules.sh}"

  data_home="$(modules_data_home)"
}

testModulesDataHomeDefaultsToXdgDataHome() {
  run modules_data_home

  assertTrue 'function failed' "$return_status"
  assertStdoutContains '.local/share/anvil'
  assertStderrNull
}

testModulesDataHomeRespectsXdgDataHomeEnvVar() {
  XDG_DATA_HOME="$tmpdir/custom_data"
  run modules_data_home

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "$XDG_DATA_HOME/anvil"
  assertStderrNull
}

testModulesPathReturnsModulesSubdir() {
  run modules_path "$data_home"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains '.local/share/anvil/modules'
  assertStderrNull
}

testModulesPathForReturnsNamedDir() {
  run module_path_for "$data_home" "mypkg"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains '.local/share/anvil/modules/mypkg'
  assertStderrNull
}

testModulesLockPathDefaultsToXdgConfigHome() {
  run modules_lock_path

  assertTrue 'function failed' "$return_status"
  assertStdoutContains '.config/anvil/modules.lock.json'
  assertStderrNull
}

testModulesIsInstalledReturnsFalseWhenMissing() {
  run module_is_installed "$data_home" "nonexistent"

  assertFalse 'should return false for missing module' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModulesIsInstalledReturnsTrueWhenPresent() {
  local mod_dir
  mod_dir="$(module_path_for "$data_home" "present")"
  mkdir -p "$mod_dir"

  run module_is_installed "$data_home" "present"

  assertTrue 'should return true for present module' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModulesInstalledNamesReturnsEmptyWhenNoLockFile() {
  run modules_installed_names "$(config_path)" "$data_home"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModulesInstalledNamesReturnsNamesInOrder() {
  writeConfigFile <<-EOF
	{
	  "modules":[
	    {"name":"alpha","url":"https://example.com/a.git"},
	    {"name":"beta","url":"https://example.com/b.git"}
	  ]
	}
	EOF

  local alpha_dir beta_dir
  alpha_dir="$(module_path_for "$data_home" "alpha")"
  beta_dir="$(module_path_for "$data_home" "beta")"
  mkdir -p "$alpha_dir" "$beta_dir"

  run modules_installed_names "$(config_path)" "$data_home"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains 'alpha'
  assertStdoutContains 'beta'
  assertStderrNull
}

testModulesResolveContentFindsFirstMatch() {
  writeConfigFile <<-EOF
	{
	  "modules":[
	    {"name":"first","url":"https://example.com/a.git"},
	    {"name":"second","url":"https://example.com/b.git"}
	  ]
	}
	EOF

  local first_tags second_tags
  first_tags="$(module_path_for "$data_home" "first")/tags"
  second_tags="$(module_path_for "$data_home" "second")/tags"
  mkdir -p "$first_tags" "$second_tags"
  echo '{"name":"base"}' >"$first_tags/base.json"
  echo '{"name":"base"}' >"$second_tags/base.json"

  run modules_resolve_content "$(config_path)" "$data_home" "tags" "base.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains 'first'
  assertStdoutContains 'base.json'
  assertStderrNull
}

testModulesResolveContentReturnsFailureWhenMissing() {
  writeConfigFile <<-EOF
	{
	  "modules":[
	    {"name":"alpha","url":"https://example.com/a.git"}
	  ]
	}
	EOF

  mkdir -p "$(module_path_for "$data_home" "alpha")/tags"

  run modules_resolve_content \
    "$(config_path)" \
    "$data_home" \
    "tags" \
    "nonexistent.json"

  assertFalse 'should fail when not found' "$return_status"
  assertStdoutNull
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../$shunit2RelRoot"
