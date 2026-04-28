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

  . "$SRC_ROOT/lib/anvil/modules.sh"
}

runCli() {
  run "$root/bin/anvil" "$@"
}

# Stubs curl to return a fake GitHub API response for a given latest version.
stubCurlLatestVersion() {
  local latest="$1"

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
	
	printf '{"tag_name":"v${latest}","name":"Anvil ${latest}"}' >"\$out"
	EOF
  chmod +x "$tmpdir/bin/curl"
  PATH="$tmpdir/bin:$PATH"
}

# Stubs all download tools to fail.
stubNetworkFailure() {
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
}

testCmdSelfCheckHelpShortFlag() {
  runCli self check -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'self check'
  assertStderrNull
}

testCmdSelfCheckHelpLongFlag() {
  runCli self check --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'self check'
  assertStderrNull
}

testCmdSelfCheckExitsZeroWhenUpToDate() {
  # The current installed version is whatever is in bin/anvil (e.g. 0.1.0).
  # Stub the latest version to match.
  local current_version
  current_version="$(grep '^  version=' "$root/bin/anvil" | head -1 \
    | sed 's/.*version="\(.*\)"/\1/')"
  stubCurlLatestVersion "$current_version"

  runCli self check

  assertTrue 'should exit 0 when up to date' "$return_status"
  assertStdoutContains 'up to date'
  assertStderrNull
}

testCmdSelfCheckExitsOneWhenUpdateAvailable() {
  stubCurlLatestVersion "99.99.99"

  runCli self check

  assertFalse 'should exit non-zero when update available' "$return_status"
  assertStdoutContains '99.99.99'
  assertStdoutContains 'available'
  assertStderrNull
}

testCmdSelfCheckExitsTwoOnNetworkFailure() {
  stubNetworkFailure

  run "$root/bin/anvil" self check

  assertEquals 'should exit 2 on network failure' "2" "$return_status"
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
