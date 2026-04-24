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

testCmdModuleUpdateHelpShortFlag() {
  runCli module update -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module update'
  assertStderrNull
}

testCmdModuleUpdateHelpLongFlag() {
  runCli module update --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module update'
  assertStderrNull
}

testCmdModuleUpdateCurrentPinnedCommit() {
  # Create a fake git to stub desired behavior
  mkdir -p "$tmpdir/bin"
  cat <<-'EOF' >"$tmpdir/bin/git"
	#!/usr/bin/env sh
	case "$*" in
          *"fetch origin")
	    exit 0
	    ;;
          *"reset --hard origin/abc123")
	    exit 0
	    ;;
          *"rev-parse HEAD")
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

  local lock_file
  lock_file="$(modules_lock_path)"

  runCli module update

  assertTrue 'cli command should succeed' "$return_status"
  assertStdoutContains 'Updating'
  assertStdoutContains 'abc123'
  assertStdoutContains 'Lock file current'
  assertStderrNull
  assertTrue 'module dir should exist' \
    "[ -d '${HOME}/.local/share/anvil/modules/pinned' ]"
  assertJsonFromFile "$lock_file" ".modules | length == 1"
  assertJsonFromFile "$lock_file" '.modules[0] | .name == "pinned"'
  assertJsonFromFile "$lock_file" \
    '.modules[0] | .url == "https://github.com/user/pinned.git"'
  assertJsonFromFile "$lock_file" '.modules[0] | .commit == "abc123"'
}

testCmdModuleUpdateOutdatedTag() {
  # Create a fake git to stub desired behavior
  mkdir -p "$tmpdir/bin"
  cat <<-'EOF' >"$tmpdir/bin/git"
	#!/usr/bin/env sh
	case "$*" in
          *"fetch origin")
	    exit 0
	    ;;
          *"reset --hard origin/v1.0.0")
	    exit 0
	    ;;
          *"rev-parse HEAD")
	    echo "def456"
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
	      "name":"tagged",
	      "url":"https://github.com/user/tagged.git",
	      "tag":"v1.0.0"
	    }
	  ]
	}
	EOF
  writeLockFile <<-EOF
	{
	  "modules":[
	    {
	      "name":"tagged",
	      "url":"https://github.com/user/tagged.git",
	      "commit":"abc123"
	    }
	  ]
	}
	EOF
  writeModuleFixture "tagged"

  local lock_file
  lock_file="$(modules_lock_path)"

  runCli module update

  assertTrue 'cli command should succeed' "$return_status"
  assertStdoutContains 'Updating'
  assertStdoutContains 'v1.0.0'
  assertStderrNull
  assertTrue 'module dir should exist' \
    "[ -d '${HOME}/.local/share/anvil/modules/tagged' ]"
  assertJsonFromFile "$lock_file" ".modules | length == 1"
  assertJsonFromFile "$lock_file" '.modules[0] | .name == "tagged"'
  assertJsonFromFile "$lock_file" \
    '.modules[0] | .url == "https://github.com/user/tagged.git"'
  assertJsonFromFile "$lock_file" '.modules[0] | .commit == "def456"'
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
