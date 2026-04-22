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

testModulesLockExistsWithLockFile() {
  local lock_file
  lock_file="$(modules_lock_path)"
  mkdir -p "$(dirname "$lock_file")"
  touch "$lock_file"

  run modules_lock_exists "$lock_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModulesLockExistsMissingLockFile() {
  local lock_file
  lock_file="$(modules_lock_path)"

  run modules_lock_exists "$lock_file"

  assertFalse 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModulesLockCreate() {
  local lock_file
  lock_file="$(modules_lock_path)"

  run modules_lock_create "$lock_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
  assertJsonFromFile "$lock_file" ".modules | length == 0"
}

testModulesLockCreateFileAlreadyExists() {
  local lock_file
  lock_file="$(modules_lock_path)"
  mkdir -p "$(dirname "$lock_file")"
  touch "$lock_file"

  run modules_lock_create "$lock_file"

  assertFalse 'function failed' "$return_status"
  assertStdoutNull
  assertStderrContains "file already exists"
}

testModuleLockJsonForMissingLockFile() {
  local lock_file
  lock_file="$(modules_lock_path)"

  run module_lock_json_for "$lock_file" "nonexistent"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModuleLockJsonForMissingEntry() {
  local lock_file
  lock_file="$(modules_lock_path)"

  mkdir -p "$(dirname "$lock_file")"
  cat <<-EOF >"$lock_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com","commit":"abc123"}
	  ]
	} 
	EOF

  run module_lock_json_for "$lock_file" "nonexistent"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModuleLockJsonForMatchingEntry() {
  local lock_file
  lock_file="$(modules_lock_path)"

  mkdir -p "$(dirname "$lock_file")"
  cat <<-EOF >"$lock_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com","commit":"abc123"}
	  ]
	} 
	EOF

  run module_lock_json_for "$lock_file" "foo"

  local actual
  actual="$tmpdir/out.json"
  cp "$stdout" "$actual"

  assertTrue 'function failed' "$return_status"
  assertJsonFromFile "$actual" '.name == "foo"'
  assertJsonFromFile "$actual" '.url == "https://example.com"'
  assertJsonFromFile "$actual" '.commit == "abc123"'
  assertStderrNull
}

testModuleConfigJsonForMissingConfigFile() {
  local config_file
  config_file="$(config_path)"

  run module_config_json_for "$config_file" "nonexistent"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModuleConfigJsonForMissingEntry() {
  local config_file
  config_file="$(config_path)"

  mkdir -p "$(dirname "$config_file")"
  cat <<-EOF >"$config_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com"}
	  ]
	} 
	EOF

  run module_config_json_for "$config_file" "nonexistent"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModuleConfigJsonForMatchingEntry() {
  local config_file
  config_file="$(config_path)"

  mkdir -p "$(dirname "$config_file")"
  cat <<-EOF >"$config_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com"}
	  ]
	} 
	EOF

  run module_config_json_for "$config_file" "foo"

  local actual
  actual="$tmpdir/out.json"
  cp "$stdout" "$actual"

  assertTrue 'function failed' "$return_status"
  assertJsonFromFile "$actual" '.name == "foo"'
  assertJsonFromFile "$actual" '.url == "https://example.com"'
  assertStderrNull
}

testModuleConfigRemoveForMissingConfigFile() {
  local config_file
  config_file="$(config_path)"

  run module_config_remove_for "$config_file" "nonexistent"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModuleConfigRemoveForMissingEntry() {
  local config_file
  config_file="$(config_path)"

  mkdir -p "$(dirname "$config_file")"
  cat <<-EOF >"$config_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com"}
	  ]
	} 
	EOF

  run module_config_remove_for "$config_file" "nonexistent"

  assertTrue 'function failed' "$return_status"
  assertStderrNull
}

testModuleConfigRemoveForMatchingEntry() {
  local config_file
  config_file="$(config_path)"

  mkdir -p "$(dirname "$config_file")"
  cat <<-EOF >"$config_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://foo.example.com"},
	    {"name":"bar","url":"https://bar.example.com"}
	  ]
	} 
	EOF

  run module_config_remove_for "$config_file" "foo"

  assertTrue 'function failed' "$return_status"
  assertJsonFromFile "$config_file" '.modules | length == 1'
  assertJsonFromFile "$config_file" '.modules[0].name == "bar"'
  assertStderrNull
}

testModuleLockRemoveForMissingLockFile() {
  local lock_file
  lock_file="$(modules_lock_path)"

  run module_lock_remove_for "$lock_file" "nonexistent"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testModuleLockRemoveForMissingEntry() {
  local lock_file
  lock_file="$(modules_lock_path)"

  mkdir -p "$(dirname "$lock_file")"
  cat <<-EOF >"$lock_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com"}
	  ]
	} 
	EOF

  run module_lock_remove_for "$lock_file" "nonexistent"

  assertTrue 'function failed' "$return_status"
  assertStderrNull
}

testModuleLockRemoveForMatchingEntry() {
  local lock_file
  lock_file="$(modules_lock_path)"

  mkdir -p "$(dirname "$lock_file")"
  cat <<-EOF >"$lock_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://foo.example.com"},
	    {"name":"bar","url":"https://bar.example.com"}
	  ]
	} 
	EOF

  run module_lock_remove_for "$lock_file" "foo"

  assertTrue 'function failed' "$return_status"
  assertJsonFromFile "$lock_file" '.modules | length == 1'
  assertJsonFromFile "$lock_file" '.modules[0].name == "bar"'
  assertStderrNull
}

testModuleLockUpdateForNoConfigFile() {
  local config_file
  config_file="$(config_path)"
  local lock_file
  lock_file="$(modules_lock_path)"

  assertTrue 'config file exists' "[ ! -f '$config_file' ]"

  run module_lock_update_for "$config_file" "$lock_file" "foo" "abc123"

  assertFalse 'function failed' "$return_status"
  assertStdoutContains "No lock file entry"
  assertStderrNull
}

testModuleLockUpdateForNoLockFile() {
  local config_file
  config_file="$(config_path)"
  local lock_file
  lock_file="$(modules_lock_path)"

  mkdir -p "$(dirname "$config_file")"
  cat <<-EOF >"$config_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com"}
	  ]
	} 
	EOF

  assertTrue 'lock file exists' "[ ! -f '$lock_file' ]"

  run module_lock_update_for "$config_file" "$lock_file" "foo" "abc123"

  assertTrue 'lock file missing' "[ -f '$lock_file' ]"
  assertJsonFromFile "$lock_file" \
    '.modules[] | select(.name == "foo") | .url == "https://example.com"'
  assertJsonFromFile "$lock_file" \
    '.modules[] | select(.name == "foo") | .commit == "abc123"'
}

testModuleLockUpdateForWithBranch() {
  local config_file
  config_file="$(config_path)"
  local lock_file
  lock_file="$(modules_lock_path)"

  mkdir -p "$(dirname "$config_file")"
  cat <<-EOF >"$config_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com","branch":"dev"}
	  ]
	} 
	EOF

  assertTrue 'lock file exists' "[ ! -f '$lock_file' ]"

  run module_lock_update_for "$config_file" "$lock_file" "foo" "abc123"

  assertTrue 'lock file missing' "[ -f '$lock_file' ]"
  assertJsonFromFile "$lock_file" \
    '.modules[] | select(.name == "foo") | .url == "https://example.com"'
  assertJsonFromFile "$lock_file" \
    '.modules[] | select(.name == "foo") | .commit == "abc123"'
  assertJsonFromFile "$lock_file" \
    '.modules[] | select(.name == "foo") | .branch == "dev"'
}

testModuleInstall() {
  local mod_path
  mod_path="$(module_path_for "$data_home" "great")"
  mkdir -p "$(dirname "$mod_path")"

  # Use a fake git that creates the directory without actually cloning
  mkdir -p "$tmpdir/bin"
  cat <<-'EOF' >"$tmpdir/bin/git"
	#!/usr/bin/env sh
	mkdir -p "$3/tags" "$3/roles"
	echo '{"name":"great"}' >"$3/module.json"
	EOF
  chmod +x "$tmpdir/bin/git"
  PATH="$tmpdir/bin:$PATH"

  _ensure_git_called=""
  # shellcheck disable=SC2329
  ensure_git() { _ensure_git_called="yes"; }

  assertTrue 'tags dir exists' "[ ! -d '$mod_path/tags' ]"
  assertTrue 'roles dir exists' "[ ! -d '$mod_path/roles' ]"

  run module_install "$mod_path" "https://example.com"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ensure_git not called' "yes" "$_ensure_git_called"
  assertTrue 'tags dir not exists' "[ -d '$mod_path/tags' ]"
  assertTrue 'roles dir not exists' "[ -d '$mod_path/roles' ]"
  assertStdoutContains "great"
  assertStderrNull
}

testModuleInstallWithCommit() {
  local mod_path
  mod_path="$(module_path_for "$data_home" "great")"
  mkdir -p "$(dirname "$mod_path")"

  _ensure_git_called=""
  # shellcheck disable=SC2329
  ensure_git() { _ensure_git_called="yes"; }
  # shellcheck disable=SC2329
  indent() { "$@"; }

  _clone_called=""
  _checkout_called=""
  # shellcheck disable=SC2329
  git() {
    case "$*" in
      *"clone https://example.com "*)
        _clone_called="yes"
        ;;
      *"checkout abc123")
        _checkout_called="yes"
        ;;
    esac
  }

  run module_install "$mod_path" "https://example.com" "abc123"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ensure_git not called' "yes" "$_ensure_git_called"
  assertEquals 'git clone not called' "yes" "$_clone_called"
  assertEquals 'git checkout not called' "yes" "$_checkout_called"
  assertStdoutContains "great"
  assertStderrNull
}

testModuleInstallFromLockNoLockFile() {
  local lock_file
  lock_file="$(modules_lock_path)"

  # shellcheck disable=SC2329
  git() { return 1; }

  assertTrue 'lock file exists' "[ ! -f '$lock_file' ]"

  run module_install_from_lock "$data_home" "$lock_file" "foo"

  assertFalse 'function succeeded' "$return_status"
  assertStdoutContains "No lock file entry"
  assertStderrNull
}

testModuleInstallFromLockNoUrl() {
  local lock_file
  lock_file="$(modules_lock_path)"

  # {"name":"foo","url":"https://example.com","commit":"abc123"}
  mkdir -p "$(dirname "$lock_file")"
  cat <<-EOF >"$lock_file"
	{
	  "modules":[
	    {"name":"foo","commit":"abc123"}
	  ]
	} 
	EOF

  # shellcheck disable=SC2329
  git() { return 1; }

  run module_install_from_lock "$data_home" "$lock_file" "foo"

  assertFalse 'function succeeded' "$return_status"
  assertStdoutContains "missing url field"
  assertStderrNull
}

testModuleInstallFromLockNoCommit() {
  local lock_file
  lock_file="$(modules_lock_path)"

  mkdir -p "$(dirname "$lock_file")"
  cat <<-EOF >"$lock_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com"}
	  ]
	} 
	EOF

  # shellcheck disable=SC2329
  git() { return 1; }

  run module_install_from_lock "$data_home" "$lock_file" "foo"

  assertFalse 'function succeeded' "$return_status"
  assertStdoutContains "missing commit field"
  assertStderrNull
}

testModuleInstallFromLockMissingDirClones() {
  local lock_file
  lock_file="$(modules_lock_path)"

  mkdir -p "$(dirname "$lock_file")"
  cat <<-EOF >"$lock_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com","commit":"abc123"}
	  ]
	} 
	EOF

  _clone_called=""
  _checkout_called=""
  # shellcheck disable=SC2329
  git() {
    case "$*" in
      *"clone https://example.com "*)
        _clone_called="yes"
        ;;
      *"checkout abc123")
        _checkout_called="yes"
        ;;
    esac
  }

  run module_install_from_lock "$data_home" "$lock_file" "foo"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ensure_git not called' "yes" "$_ensure_git_called"
  assertEquals 'git clone not called' "yes" "$_clone_called"
  assertEquals 'git checkout not called' "yes" "$_checkout_called"
  assertStdoutContains "foo"
  assertStderrNull
}

testModuleInstallFromLockExitingGitRepoCheckout() {
  local lock_file
  lock_file="$(modules_lock_path)"

  mkdir -p "$(dirname "$lock_file")"
  cat <<-EOF >"$lock_file"
	{
	  "modules":[
	    {"name":"foo","url":"https://example.com","commit":"abc123"}
	  ]
	} 
	EOF

  local mod_path
  mod_path="$(module_path_for "$data_home" "foo")"
  mkdir -p "$mod_path/.git"

  _clone_called=""
  _checkout_called=""
  # shellcheck disable=SC2329
  git() {
    case "$*" in
      *clone*)
        _clone_called="yes"
        ;;
      *"checkout abc123")
        _checkout_called="yes"
        ;;
    esac
  }

  run module_install_from_lock "$data_home" "$lock_file" "foo"

  assertTrue 'function failed' "$return_status"
  assertEquals 'ensure_git not called' "yes" "$_ensure_git_called"
  assertEquals 'git clone called' "" "$_clone_called"
  assertEquals 'git checkout not called' "yes" "$_checkout_called"
  assertStdoutNull
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

testModulesExpandUrlGithubHttpsShortForm() {
  run module_expand_url "github.com/user/repo"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "https://github.com/user/repo.git"
}

testModulesExpandUrlCodebergHttpsShortForm() {
  run module_expand_url "codeberg.org/user/repo"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "https://codeberg.org/user/repo.git"
}

testModulesExpandUrlGithubSshShortForm() {
  run module_expand_url "github.com:user/repo"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "git@github.com:user/repo.git"
}

testModulesExpandUrlCodebergSshShortForm() {
  run module_expand_url "codeberg.org:user/repo"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "git@codeberg.org:user/repo.git"
}

testModulesExpandUrlFullHttpsPassThrough() {
  run module_expand_url "https://github.com/user/repo.git"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "https://github.com/user/repo.git"
}

testModulesExpandUrlFullHttpsAppendsGit() {
  run module_expand_url "https://github.com/user/repo"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "https://github.com/user/repo.git"
}

testModulesExpandUrlFullSshPassThrough() {
  run module_expand_url "git@github.com:user/repo.git"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "git@github.com:user/repo.git"
}

testModulesExpandUrlFullSshAppendsGit() {
  run module_expand_url "git@github.com:user/repo"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "git@github.com:user/repo.git"
}

testModulesExpandUrlFullSshArbitraryHost() {
  run module_expand_url "https://git.example.com/user/repo.git"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "https://git.example.com/user/repo.git"
}

testModulesExpandUrlInvalidFails() {
  run module_expand_url "not-a-url"

  assertFalse 'should fail for invalid url' "$return_status"
}

testModulesNameFromUrlExtractsRepoName() {
  run module_name_from_url "https://github.com/user/my-modules.git"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "my-modules"
}

testModulesNameFromUrlExtractsOrgFromAnvilModuleRepoName() {
  run module_name_from_url "https://github.com/user/anvil-module.git"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "user"
}

testModulesNameFromUrlExtractsOrgFromAnvilModulesRepoName() {
  run module_name_from_url "https://github.com/user/anvil-modules.git"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "user"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../$shunit2RelRoot"
