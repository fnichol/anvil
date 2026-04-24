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

testCmdModuleCheckHelpShortFlag() {
  runCli module check -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module check'
  assertStderrNull
}

testCmdModuleCheckHelpLongFlag() {
  runCli module check --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module check'
  assertStderrNull
}

testCmdModuleCheckCurrentPinnedModules() {
  writeConfigFile <<-EOF
	{
	  "modules":[
	    {
	      "name":"pinned",
	      "url":"https://github.com/user/pinned.git",
	      "commit":"abc123"
	    }
	  ]
	}
	EOF
  writeLockFile <<-EOF
	{
	  "modules":[
	    {
	      "name":"pinned",
	      "url":"https://github.com/user/pinned.git",
	      "commit":"abc123"
	    }
	  ]
	}
	EOF
  writeModuleFixture "pinned"

  runCli module check

  assertTrue 'cli should succeed when all pinned' "$return_status"
  assertStdoutContains 'Current'
  assertStdoutContains 'pinned'
  assertStderrNull
}

testCmdModuleCheckCurrentOutdatedModules() {
  writeConfigFile <<-EOF
	{
	  "modules":[
	    {
	      "name":"pinned",
	      "url":"https://github.com/user/pinned.git",
	      "commit":"abc123"
	    }
	  ]
	}
	EOF
  writeLockFile <<-EOF
	{
	  "modules":[
	    {
	      "name":"pinned",
	      "url":"https://github.com/user/pinned.git",
	      "commit":"def456"
	    }
	  ]
	}
	EOF
  writeModuleFixture "pinned"

  runCli module check

  assertFalse 'cli should fail with outdated pinned' "$return_status"
  assertStdoutContains 'Outdated'
  assertStdoutContains 'pinned'
  assertStderrNull
}

testCmdModuleCheckReturnsZeroWhenAllUpToDate() {
  # Create a fake git to stub desired behavior
  mkdir -p "$tmpdir/bin"
  cat <<-'EOF' >"$tmpdir/bin/git"
	#!/usr/bin/env sh
	case "$*" in
          *"ls-remote https://github.com/user/mypkg.git HEAD")
	    echo "abc123"
	    ;;
	  *)
	    echo "Unexpected Git command: $*" >&2
	    exit 1
	    ;;
	esac
	EOF
  chmod +x "$tmpdir/bin/git"
  PATH="$tmpdir/bin:$PATH"

  writeConfigFile <<-EOF
	{
	  "modules":[
	    {
	      "name":"mypkg",
	      "url":"https://github.com/user/mypkg.git"
	    }
	  ]
	}
	EOF
  writeLockFile <<-EOF
	{
	  "modules":[
	    {
	      "name":"mypkg",
	      "url":"https://github.com/user/mypkg.git",
	      "commit":"abc123"
	    }
	  ]
	}
	EOF
  writeModuleFixture "mypkg"

  runCli module check

  assertTrue 'should exit 0 when up to date' "$return_status"
  assertStdoutContains "Current"
  assertStdoutContains "All modules are current"
  assertStderrNull
}

testCmdModuleCheckReturnsNonzeroWhenOutOfDate() {
  # Create a fake git to stub desired behavior
  mkdir -p "$tmpdir/bin"
  cat <<-'EOF' >"$tmpdir/bin/git"
	#!/usr/bin/env sh
	case "$*" in
          *"ls-remote https://github.com/user/current.git HEAD")
	    echo "abc123"
	    ;;
          *"ls-remote https://github.com/user/outdated.git HEAD")
	    echo "ghi789"
	    ;;
	  *)
	    echo "Unexpected Git command: $*" >&2
	    exit 1
	    ;;
	esac
	EOF
  chmod +x "$tmpdir/bin/git"
  PATH="$tmpdir/bin:$PATH"

  writeConfigFile <<-EOF
	{
	  "modules":[
	    {
	      "name":"current",
	      "url":"https://github.com/user/current.git"
	    },
	    {
	      "name":"outdated",
	      "url":"https://github.com/user/outdated.git"
	    }
	  ]
	}
	EOF
  writeLockFile <<-EOF
	{
	  "modules":[
	    {
	      "name":"current",
	      "url":"https://github.com/user/current.git",
	      "commit":"abc123"
	    },
	    {
	      "name":"outdated",
	      "url":"https://github.com/user/outdated.git",
	      "commit":"def456"
	    }
	  ]
	}
	EOF
  writeModuleFixture "current"
  writeModuleFixture "outdated"

  runCli module check

  assertFalse 'should not exit 0 when outdated' "$return_status"
  assertStdoutContains "Outdated"
  assertStdoutContains "Some modules are outdated"
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
