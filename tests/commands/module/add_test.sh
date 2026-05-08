#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../../.."

  commonOneTimeSetUp
}

setUp() {
  commonSetUp
}

runCli() {
  run "$root/bin/anvil" "$@"
}

testCmdModuleAddHelpShortFlag() {
  runCli module add -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module add'
  assertStderrNull
}

testCmdModuleAddHelpLongFlag() {
  runCli module add --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module add'
  assertStderrNull
}

testCmdModuleAddFailsWithNoUrl() {
  runCli module add

  assertFalse 'should fail without url' "$return_status"
  assertStderrContains 'URL'
}

testCmdModuleAddWritesModuleToConfig() {
  # Use a fake git that creates the directory without actually cloning
  mkdir -p "$tmpdir/bin"
  cat <<-'EOF' >"$tmpdir/bin/git"
	#!/usr/bin/env sh
	case "$*" in
	  *clone*)
	    mkdir -p "$3/tags" "$3/roles"
	    echo '{"name":"test"}' >"$3/module.json"
	    ;;
	esac
	EOF
  chmod +x "$tmpdir/bin/git"
  PATH="$tmpdir/bin:$PATH"

  writeConfigFile '{"modules":[]}'

  runCli module add "github.com/user/test-module"

  assertTrue 'cli command failed' "$return_status"
  assertStderrNull

  # Verify config.json was updated
  local config_file
  config_file="$HOME/.config/anvil/config.json"
  assertJsonFromFile "$config_file" '.modules | length == 1'
  assertJsonFromFile "$config_file" '.modules[0].name == "test-module"'
  assertJsonFromFile "$config_file" \
    '.modules[0].url == "https://github.com/user/test-module.git"'
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
