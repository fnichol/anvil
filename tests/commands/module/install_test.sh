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

testCmdModuleInstallHelpShortFlag() {
  runCli module install -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module install'
  assertStderrNull
}

testCmdModuleInstallHelpLongFlag() {
  runCli module install --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'module install'
  assertStderrNull
}

testCmdModuleInstallIsIdempotentWhenAlreadyInstalledAndUpToDate() {
  # Create a fake git to stub desired behavior
  mkdir -p "$tmpdir/bin"
  cat <<-'EOF' >"$tmpdir/bin/git"
	#!/usr/bin/env sh
	case "$*" in
          *"rev-parse HEAD")
	    echo "abc123"
	    ;;
	  *clone*)
	    echo "Git clone should not be called" >&2
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

  local lock_file
  lock_file="$(modules_lock_path)"

  runCli module install

  assertTrue 'cli command should succeed' "$return_status"
  assertStdoutContains 'Up to date'
  assertStderrNull
  assertTrue 'module dir should exist' \
    "[ -d '${HOME}/.local/share/anvil/modules/mypkg' ]"
  assertJsonFromFile "$lock_file" ".modules | length == 1"
  assertJsonFromFile "$lock_file" '.modules[0] | .name == "mypkg"'
  assertJsonFromFile "$lock_file" \
    '.modules[0] | .url == "https://github.com/user/mypkg.git"'
  assertJsonFromFile "$lock_file" '.modules[0] | .commit == "abc123"'
}

testCmdModuleInstallUpdatesWhenAlreadyInstalledAndOutOfDate() {
  # Create a fake git to stub desired behavior
  mkdir -p "$tmpdir/bin"
  cat <<-'EOF' >"$tmpdir/bin/git"
	#!/usr/bin/env sh
	case "$*" in
          *"rev-parse HEAD")
	    echo "def456"
	    ;;
          *"checkout abc123")
	    exit 0
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

  local lock_file
  lock_file="$(modules_lock_path)"

  runCli module install

  assertTrue 'cli command should succeed' "$return_status"
  assertStdoutContains 'Checking out commit'
  assertStdoutContains 'abc123'
  assertStderrNull
  assertTrue 'module dir should exist' \
    "[ -d '${HOME}/.local/share/anvil/modules/mypkg' ]"
  assertJsonFromFile "$lock_file" ".modules | length == 1"
  assertJsonFromFile "$lock_file" '.modules[0] | .name == "mypkg"'
  assertJsonFromFile "$lock_file" \
    '.modules[0] | .url == "https://github.com/user/mypkg.git"'
  assertJsonFromFile "$lock_file" '.modules[0] | .commit == "abc123"'
}

testCmdModuleInstallClonesUninstalledModuleNoLockEntry() {
  # Create a fake git to stub desired behavior
  mkdir -p "$tmpdir/bin"
  cat <<-'EOF' >"$tmpdir/bin/git"
	#!/usr/bin/env sh
	case "$*" in
	  *clone*)
	    mkdir -p "$3/tags" "$3/roles" "$3/.git"
	    echo '{"name":"test"}' >"$3/module.json"
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

  writeConfigFile \
    '{"modules":[{"name":"mypkg","url":"https://github.com/user/mypkg.git"}]}'
  # - Skip lock file createion
  # - Skip module fixture to simulate not yet on disk

  local lock_file
  lock_file="$(modules_lock_path)"

  assertFalse 'lock file does not exist' "[ -d '$lock_file' ]"

  runCli module install

  assertTrue 'cli command should succeed' "$return_status"
  assertStdoutContains "Cloning"
  assertStdoutContains "Updating modules lock file"
  assertStderrNull
  assertTrue 'module dir should exist' \
    "[ -d '${HOME}/.local/share/anvil/modules/mypkg' ]"
  assertJsonFromFile "$lock_file" ".modules | length == 1"
  assertJsonFromFile "$lock_file" '.modules[0] | .name == "mypkg"'
  assertJsonFromFile "$lock_file" \
    '.modules[0] | .url == "https://github.com/user/mypkg.git"'
  assertJsonFromFile "$lock_file" '.modules[0] | .commit == "abc123"'
}

testCmdModuleInstallClonesAndUpdatesUninstalledModuleWithLockEntry() {
  # Create a fake git to stub desired behavior
  mkdir -p "$tmpdir/bin"
  cat <<-'EOF' >"$tmpdir/bin/git"
	#!/usr/bin/env sh
	case "$*" in
	  *clone*)
	    mkdir -p "$3/tags" "$3/roles" "$3/.git"
	    echo '{"name":"test"}' >"$3/module.json"
	    ;;
	  *"checkout abc123"*)
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
  # - Skip module fixture to simulate not yet on disk

  local lock_file
  lock_file="$(modules_lock_path)"

  runCli module install

  assertTrue 'cli command should succeed' "$return_status"
  assertStdoutContains "Cloning"
  assertStdoutContains "Checking out"
  assertStdoutContains "abc123"
  assertStderrNull
  assertTrue 'module dir should exist' \
    "[ -d '${HOME}/.local/share/anvil/modules/mypkg' ]"
  assertJsonFromFile "$lock_file" ".modules | length == 1"
  assertJsonFromFile "$lock_file" '.modules[0] | .name == "mypkg"'
  assertJsonFromFile "$lock_file" \
    '.modules[0] | .url == "https://github.com/user/mypkg.git"'
  assertJsonFromFile "$lock_file" '.modules[0] | .commit == "abc123"'
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
