#!/usr/bin/env sh
# shellcheck disable=SC3043
# Test helper utilities for shUnit2

# shellcheck disable=SC2034
commonOneTimeSetUp() {
  set -u

  # Define root of project tree
  if [ -n "${TEST_ROOT:-}" ]; then
    root="$TEST_ROOT"
    SRC_ROOT="$root"
  else
    root="${0%/*}/.."
    SRC_ROOT="$root"
  fi

  __ORIG_FLAGS="$-"
  __ORIG_PATH="$PATH"
  __ORIG_TERM="$TERM"
  __ORIG_PWD="$(pwd)"

  tmpdir="$SHUNIT_TMPDIR/tmp"

  stdout="$tmpdir/stdout"
  stderr="$tmpdir/stderr"
  expected="$tmpdir/expected"
  actual="$tmpdir/actual"
  sh_script="$tmpdir/sh_script.sh"
  isolated_path="$tmpdir/isolated_path"
}

commonSetUp() {
  # Reset set flags to its original value
  set "-$__ORIG_FLAGS"
  # Reset the value of $PATH to its original value
  PATH="$__ORIG_PATH"
  # Reset the value of $TERM to its original value
  TERM="$__ORIG_TERM"
  # Restore the original working directory
  cd "$__ORIG_PWD" || return 1
  # Clean any prior test file/directory state
  rm -rf "$tmpdir"
  # Unset any prior test variable state
  unset return_status
  # Create a scratch directory that will be removed on every test
  mkdir -p "$tmpdir"

  # Ensure any existing XDG config is unset as this may come from a user's
  # shell session and isn't intended to be used in tests
  unset XDG_CONFIG_HOME
  unset XDG_STATE_HOME

  # Override home directory environment variable
  HOME="$tmpdir/home"
  mkdir -p "$HOME"
}

writeConfigFile() {
  local content="${1:-{}}"
  local location="${2:-$HOME/.config/anvil/config.json}"

  mkdir -p "$(dirname "$location")"
  echo "$content" >"$location"
}

assertStdoutEquals() {
  if [ "$#" -eq 2 ]; then
    assertEquals "$1" "$2" "$(cat "$stdout")"
  else
    assertEquals 'stdout not equal' "$1" "$(cat "$stdout")"
  fi
}

assertStdoutStripAnsiEquals() {
  if [ "$#" -eq 2 ]; then
    assertEquals "$1" "$2" "$(stripAnsi <"$stdout")"
  else
    assertEquals 'stdout (strip ANSI) not equal' "$1" "$(stripAnsi <"$stdout")"
  fi
}

assertStdoutContains() {
  if [ "$#" -eq 2 ]; then
    assertTrue "$1" "grep -E '$2' <'$stdout'"
  else
    assertTrue 'stdout does not contain' "grep -E '$1' <'$stdout'"
  fi
}

assertStdoutStripAnsiContains() {
  stripAnsi <"$stdout" >"$tmpdir/stdout_no_ansi"

  if [ "$#" -eq 2 ]; then
    assertTrue "$1" "grep -E '$2' <'$tmpdir/stdout_no_ansi'"
  else
    assertTrue 'stdout does not contain' "grep -E '$1' <'$tmpdir/stdout_no_ansi'"
  fi
}

assertStdoutNull() {
  assertTrue 'stdout is not empty' "[ ! -s '$stdout' ]"
}

assertStderrEquals() {
  if [ "$#" -eq 2 ]; then
    assertEquals "$1" "$2" "$(cat "$stderr")"
  else
    assertEquals 'stderr not equal' "$1" "$(cat "$stderr")"
  fi
}

assertStderrStripAnsiEquals() {
  if [ "$#" -eq 2 ]; then
    assertEquals "$1" "$2" "$(stripAnsi <"$stderr")"
  else
    assertEquals 'stderr (strip ANSI) not equal' "$1" "$(stripAnsi <"$stderr")"
  fi
}

assertStderrContains() {
  if [ "$#" -eq 2 ]; then
    assertTrue "$1" "grep -E '$2' <'$stderr'"
  else
    assertTrue 'stderr does not contain' "grep -E '$1' <'$stderr'"
  fi
}

assertStderrStripAnsiContains() {
  stripAnsi <"$stderr" >"$tmpdir/stderr_no_ansi"

  if [ "$#" -eq 2 ]; then
    assertTrue "$1" "grep -E '$2' <'$tmpdir/stderr_no_ansi'"
  else
    assertTrue 'stderr does not contain' "grep -E '$1' <'$tmpdir/stderr_no_ansi'"
  fi
}

assertStderrNull() {
  assertTrue 'stderr is not empty' "[ ! -s '$stderr' ]"
}

assertJson() {
  echo "echo \"$1\" | jq -e '$2'" >"$sh_script"
  run "${SHELL_BIN:-sh}" "$sh_script"

  assertTrue "jq execution failed ($2)" "$return_status"
}

assertJsonFromFile() {
  echo "jq -e '$2' <$1" >"$sh_script"
  run "${SHELL_BIN:-sh}" "$sh_script"

  assertTrue "jq execution failed ($2)" "$return_status"
}

# Run command and capture stdout/stderr
run() {
  # Implementation inspired by `run` in bats
  # See: https://git.io/fjCcr
  _origFlags="$-"
  set +e
  # functrace is not supported by all shells, eg: dash
  if set -o | "${GREP:-grep}" -q '^functrace'; then
    # shellcheck disable=SC3041
    set +T
  fi
  # errtrace is not supported by all shells, eg: ksh
  if set -o | "${GREP:-grep}" -q '^errtrace'; then
    # shellcheck disable=SC3041
    set +E
  fi
  "$@" >"$stdout" 2>"$stderr"
  return_status=$?
  set "-$_origFlags"
  unset _origFlags

  return "$return_status"
}

__setup_sh_script() {
  cat "${SRC:?SRC not set}" >"$sh_script"
  cat "${0%/*}/_ksh_local.sh" >>"$sh_script"
  echo >>"$sh_script"
}

run_in_sh_script() {
  __setup_sh_script
  while read -r line; do
    echo "$line" >>"$sh_script"
  done

  run "${SHELL_BIN:-sh}" "$sh_script"
}

run_in_sh_script_and_signal() {
  __setup_sh_script
  while read -r line; do
    echo "$line" >>"$sh_script"
  done

  echo "
    # Run the script with the shell interpreter in the background
    ${SHELL_BIN:-sh} $sh_script &
    # Capture the pid of the script
    bgps=\$!
    # Sleep to wait for script to start running and to start writing to output
    # streams
    sleep 0.05
    # Send the given signal to the script process
    kill -s '$1' \$bgps
    # Wait for the script process to terminate
    wait \$bgps
    # Return the exit code from the script process
    exit $?
  " >"$tmpdir/run_in_bg.sh"

  run "${SHELL_BIN:-sh}" "$tmpdir/run_in_bg.sh"
}

run_with_sh_script() {
  __setup_sh_script
  echo '"$@"' >>"$sh_script"

  run "${SHELL_BIN:-sh}" "$sh_script" "$@"
}

debugLastRun() {
  echo "======================"
  echo "Last 'run' invocation:"
  echo "----------------------"
  echo
  echo "return_status=$return_status"
  echo
  echo "stdout:"
  echo "---"
  cat "$stdout"
  echo "---"
  echo
  echo "stderr:"
  echo "---"
  cat "$stderr"
  echo "---"
  echo "======================"
}

stripAnsi() {
  case "$(uname -s)" in
    FreeBSD)
      gsed -r 's,\x1B\[[0-9;]*[a-zA-Z],,g'
      ;;
    *)
      # The `sed` implementation on macOS does not support either `\x1b` nor
      # the `-r` flag, and dash has a bug
      # (https://bugs.launchpad.net/ubuntu/+source/dash/+bug/1499473) where
      # `\xNN` hex bytes can't be printed, therefore we'll emit the correct
      # byte in octal with a `printf` subshell.
      sed 's,'"$(printf "\033")"'\[[0-9;]*[a-zA-Z],,g'
      ;;
  esac
}

isolatedPathFor() {
  mkdir -p "$isolated_path"

  for _bin in "$@"; do
    if command -v "$_bin" >/dev/null; then
      ln -snf "$(command -v "$_bin")" "$isolated_path/$_bin"
    fi
  done
}

shell_compat() {
  if [ -n "${ZSH_VERSION:-}" ]; then
    # shellcheck disable=SC3040
    set -o shwordsplit
    SHUNIT_PARENT="$1"
  fi
}

# shellcheck disable=SC2034
shunit2RelRoot="tmp/shunit2/shunit2"
shunit2="${0%/*}/../$shunit2RelRoot"
