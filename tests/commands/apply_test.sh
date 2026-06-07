#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp
}

setUp() {
  commonSetUp

  . "$SRC_ROOT/lib/anvil/state.sh"

  test_config="$tmpdir/config.json"
}

runCli() {
  ANVIL_CONFIG_PATH="$test_config" __ANVIL_LOGGING__=1 \
    run "$root/bin/anvil" "$@"
}

testCmdConfigHelpShortFlag() {
  runCli apply -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'apply'
  assertStderrNull
}

testCmdConfigHelpLongFlag() {
  runCli apply --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'apply'
  assertStderrNull
}

testCmdApplyHelpShowsNoSudoFlag() {
  runCli apply --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'no-sudo'
}

testCmdApplyNoConfigShowsError() {
  runCli apply

  assertFalse 'apply should fail without config' "$return_status"
  assertStdoutContains 'No config found at:'
  assertStderrContains 'Config file not found'
}

testApplyDryRunWithConfig() {
  # Create minimal config
  cat >"$test_config" <<-'EOF'
	{
	  "modules": [{"name":"foo","url":"https://example.com"}],
	  "tags": ["alfa"],
	  "skip_steps": [],
	  "custom_packages": {
	    "add": [],
	    "remove": []
	  }
	}
	EOF
  writeModuleFixture "foo" "$root/tests/fixtures/data/tags"

  runCli apply --dry-run

  assertTrue 'apply --dry-run should succeeed' "$return_status"
  # TODO: this may come back, depending on output of re-assembled functionality
  #
  # # Should show either packages to install or "converged" message
  # assertTrue 'Missing expected output' \
  #   "cat '$stdout' | grep -qE '(Would Install|System Converged|No changes)'"
}

testApplyNoSudoDeclaresElevationDisabled() {
  cat >"$test_config" <<-'EOF'
	{
	  "modules": [{"name":"foo","url":"https://example.com"}],
	  "tags": ["alfa"],
	  "skip_steps": [],
	  "custom_packages": {
	    "add": [],
	    "remove": []
	  }
	}
	EOF
  writeModuleFixture "foo" "$root/tests/fixtures/data/tags"

  runCli apply --no-sudo --dry-run

  assertTrue 'apply --no-sudo --dry-run should succeed' "$return_status"
  assertStdoutContains 'Privilege elevation disabled'
}

testCmdApplyFailsWithNoModules() {
  echo '{"modules":[]}' >"$test_config"

  runCli apply

  assertFalse 'should fail with no modules' "$return_status"
  assertStdoutContains 'No modules are installed'
  assertStderrContains 'Nothing configured to apply'
}

testApplyAdvisoryShownWhenUpdateAvailable() {
  cat >"$test_config" <<-'EOF'
	{
	  "modules": [{"name":"foo","url":"https://example.com"}],
	  "tags": ["alfa"],
	  "skip_steps": [],
	  "custom_packages": {"add":[],"remove":[]}
	}
	EOF
  writeModuleFixture "foo" "$root/tests/fixtures/data/tags"

  mkdir -p "$tmpdir/bin"
  cat >"$tmpdir/bin/curl" <<-'EOF'
	#!/usr/bin/env sh
	while [ $# -gt 0 ]; do
	  case "$1" in
	    -o)
	      shift
	      out="$1"
	      ;;
	  esac
	  shift
	done
	
	printf '{"tag_name":"v99.99.99"}' >"$out"
	EOF
  chmod +x "$tmpdir/bin/curl"
  PATH="$tmpdir/bin:$PATH"

  runCli apply --dry-run

  assertTrue 'apply --dry-run should succeed' "$return_status"
  assertStdoutContains '99.99.99'
  assertStdoutContains 'available'
  assertStdoutContains 'self update'
}

testApplyAdvisoryNotShownWhenUpToDate() {
  cat >"$test_config" <<-'EOF'
	{
	  "modules": [{"name":"foo","url":"https://example.com"}],
	  "tags": ["alfa"],
	  "skip_steps": [],
	  "custom_packages": {"add":[],"remove":[]}
	}
	EOF
  writeModuleFixture "foo" "$root/tests/fixtures/data/tags"

  local current_version
  current_version="$(grep '^  version=' "$root/bin/anvil" | head -1 \
    | sed 's/.*version="\(.*\)"/\1/')"

  mkdir -p "$tmpdir/bin"
  cat >"$tmpdir/bin/curl" <<-EOF
	#!/usr/bin/env sh
	while [ \$# -gt 0 ]; do
	  case "\$1" in
	    -o)
	      shift
	      out="\$1"
	      ;;
	  esac
	  shift
	done
	
	printf '{"tag_name":"v${current_version}"}' >"\$out"
	EOF
  chmod +x "$tmpdir/bin/curl"
  PATH="$tmpdir/bin:$PATH"

  runCli apply --dry-run

  assertTrue 'apply --dry-run should succeed' "$return_status"
  assertStdoutNotContains 'self update'
  assertStderrNull
}

testApplyAdvisoryNotShownOnNetworkFailure() {
  cat >"$test_config" <<-'EOF'
	{
	  "modules": [{"name":"foo","url":"https://example.com"}],
	  "tags": ["alfa"],
	  "skip_steps": [],
	  "custom_packages": {"add":[],"remove":[]}
	}
	EOF
  writeModuleFixture "foo" "$root/tests/fixtures/data/tags"

  mkdir -p "$tmpdir/bin"
  cat >"$tmpdir/bin/curl" <<-'EOF'
	#!/usr/bin/env sh
	exit 1
	EOF
  cat >"$tmpdir/bin/wget" <<-'EOF'
	#!/usr/bin/env sh
	exit 1
	EOF
  cat >"$tmpdir/bin/ftp" <<-'EOF'
	#!/usr/bin/env sh
	exit 1
	EOF
  chmod +x "$tmpdir/bin/curl" "$tmpdir/bin/wget" "$tmpdir/bin/ftp"
  PATH="$tmpdir/bin:$PATH"

  runCli apply --dry-run

  assertTrue 'apply should succeed even when network fails' "$return_status"
  assertStdoutNotContains 'self update'
  assertStderrNull
}

testApplyAdvisoryUsesCacheWhenFresh() {
  cat >"$test_config" <<-'EOF'
	{
	  "modules": [{"name":"foo","url":"https://example.com"}],
	  "tags": ["alfa"],
	  "skip_steps": [],
	  "custom_packages": {"add":[],"remove":[]}
	}
	EOF
  writeModuleFixture "foo" "$root/tests/fixtures/data/tags"

  # Write a fresh cache entry with a future next-check timestamp
  local future_ts
  future_ts="$(($(date -u +%s) + 86400))"
  XDG_STATE_HOME="$tmpdir/state" \
    run state_write_update_check "99.99.99" "$future_ts"

  # Stub network to fail — the cache should be used instead
  mkdir -p "$tmpdir/bin"
  printf '#!/usr/bin/env sh\nexit 1\n' >"$tmpdir/bin/curl"
  chmod +x "$tmpdir/bin/curl"
  PATH="$tmpdir/bin:$PATH"

  XDG_STATE_HOME="$tmpdir/state" runCli apply --dry-run

  assertTrue 'apply should succeed' "$return_status"
  assertStdoutContains '99.99.99'
  assertStdoutContains 'self update'
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
