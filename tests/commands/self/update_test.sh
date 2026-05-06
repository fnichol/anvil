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

# Stubs curl for version check AND tarball download.
#
# * `@param [String]` latest version to report
# * `@param [String]` tarball dir to serve from
stubCurlForUpdate() {
  local latest_version="$1"
  local tarball_dir="$2"

  mkdir -p "$tmpdir/bin"
  cat >"$tmpdir/bin/curl" <<-EOF
	#!/usr/bin/env sh
	
	url=""
	out=""
	
	while [ \$# -gt 0 ]; do
	  case "\$1" in
	    -o)
	      shift
	      out="\$1"
	      ;;
	    http*)
	      url="\$1"
	      ;;
	  esac
	  shift
	done
	
	case "\$url" in
	  *releases/latest*)
	    printf '{"tag_name":"v${latest_version}"}' >"\$out"
	    ;;
	  *.tar.gz.md5)
	    printf '%s  anvil-${latest_version}.tar.gz\n' \
	      "\$(md5sum "${tarball_dir}/anvil-${latest_version}.tar.gz" \
	         | awk '{print \$1}')" >"\$out"
	    ;;
	  *.tar.gz.sha256)
	    sha256sum "${tarball_dir}/anvil-${latest_version}.tar.gz" \
	      | awk '{print \$1 "  anvil-${latest_version}.tar.gz"}' >"\$out"
	    ;;
	  *.tar.gz)
	    cp "${tarball_dir}/anvil-${latest_version}.tar.gz" "\$out"
	    ;;
	esac
	EOF
  chmod +x "$tmpdir/bin/curl"
  PATH="$tmpdir/bin:$PATH"
}

# Creates a minimal fake release tarball.
#
# * `@param [String]` tarball dir
# * `@param [String]` version
makeFakeTarball() {
  local dir="$1"
  local ver="$2"

  local src="$tmpdir/fake_src/anvil-$ver"
  mkdir -p "$src/bin" "$src/lib" "$src/vendor"

  cat >"$src/bin/anvil" <<-EOF
	#!/usr/bin/env sh
	echo "anvil $ver"
	EOF
  chmod +x "$src/bin/anvil"
  mkdir -p "$dir"
  (cd "$tmpdir/fake_src" && tar czf "$dir/anvil-$ver.tar.gz" "anvil-$ver")
}

testCmdSelfUpdateHelpShortFlag() {
  runCli self update -h

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'self update'
  assertStderrNull
}

testCmdSelfUpdateHelpLongFlag() {
  runCli self update --help

  assertTrue 'cli command failed' "$return_status"
  assertStdoutContains 'USAGE:'
  assertStdoutContains 'self update'
  assertStderrNull
}

testCmdSelfUpdateGuardsAgainstDevCheckout() {
  # Note that as the test runs from the Git repo source root which has a
  # `.git/` directory, the dev checkout guard should fire immediately.

  runCli self update

  assertFalse 'should fail on dev checkout' "$return_status"
  assertStdoutNull
  assertStderrContains 'development checkout'
}

testCmdSelfUpdateAlreadyUpToDate() {
  # Simulate an installed release (no .git in SRC_ROOT).
  # Set XDG_DATA_HOME so installs dir matches SRC_ROOT parent.

  local installs_dir="$tmpdir/share/anvil/installs"

  local current_version
  current_version="$(cat "$root/VERSION.txt")"

  mkdir -p "$installs_dir/$current_version"
  ln -sfn "$current_version" "$installs_dir/current"

  # Stub curl to report same version as installed
  local tarball_dir="$tmpdir/tarballs"
  makeFakeTarball "$tarball_dir" "$current_version"
  stubCurlForUpdate "$current_version" "$tarball_dir"

  ANVIL_FORCE_UPDATE=1 XDG_DATA_HOME="$tmpdir/share" \
    run "$root/bin/anvil" self update

  assertTrue 'should succeed when already current' "$return_status"
  assertStdoutContains 'Up to date'
  assertStderrNull
}

testCmdSelfUpdateInstallsNewVersion() {
  local installs_dir="$tmpdir/share/anvil/installs"

  local current_version
  current_version="$(cat "$root/VERSION.txt")"

  mkdir -p "$installs_dir/$current_version"
  ln -sfn "$current_version" "$installs_dir/current"

  local new_version="99.0.0"

  local tarball_dir="$tmpdir/tarballs"
  makeFakeTarball "$tarball_dir" "$new_version"
  stubCurlForUpdate "$new_version" "$tarball_dir"

  ANVIL_FORCE_UPDATE=1 XDG_DATA_HOME="$tmpdir/share" \
    run "$root/bin/anvil" self update

  assertTrue 'update should succeed' "$return_status"
  assertTrue 'new version dir should exist' \
    "[ -d '$installs_dir/$new_version' ]"
  assertTrue 'new version bin/anvil should exist' \
    "[ -f '$installs_dir/$new_version/bin/anvil' ]"
  local link_target
  link_target="$(readlink "$installs_dir/current")"
  assertEquals 'current symlink should point to new version' \
    "$new_version" "$link_target"
  assertStdoutContains "$new_version"
  assertStderrNull
}

testCmdSelfUpdateGitRefInstallsToGitPrefixedDir() {
  local installs_dir="$tmpdir/share/anvil/installs"

  local current_version
  current_version="$(cat "$root/VERSION.txt")"

  mkdir -p "$installs_dir/$current_version"
  ln -sfn "$current_version" "$installs_dir/current"

  # Stub curl to serve a fake git archive tarball (same structure as release)
  local tarball_dir="$tmpdir/tarballs"
  # GitHub archive tarball has repo-ref/ prefix
  local src="$tmpdir/fake_archive/anvil-my-branch"
  mkdir -p "$src/bin" "$src/lib" "$src/vendor"
  printf '#!/usr/bin/env sh\necho "anvil 0.1.0-dev"\n' >"$src/bin/anvil"
  chmod +x "$src/bin/anvil"
  mkdir -p "$tarball_dir"
  (cd "$tmpdir/fake_archive" \
    && tar czf "$tarball_dir/my-branch.tar.gz" "anvil-my-branch")

  mkdir -p "$tmpdir/bin"
  cat >"$tmpdir/bin/curl" <<-EOF
	#!/usr/bin/env sh
	
	out=""
	
	while [ \$# -gt 0 ]; do
	  case "\$1" in
	    -o)
	      shift
	      out="\$1"
	      ;;
	  esac
	  shift
	done
	
	cp "${tarball_dir}/my-branch.tar.gz" "\$out"
	EOF
  chmod +x "$tmpdir/bin/curl"
  PATH="$tmpdir/bin:$PATH"

  ANVIL_FORCE_UPDATE=1 XDG_DATA_HOME="$tmpdir/share" \
    run "$root/bin/anvil" self update --git=my-branch

  assertTrue 'git-ref update should succeed' "$return_status"
  assertTrue 'git-prefixed dir should exist' \
    "[ -d '$installs_dir/git-my-branch' ]"
  local link_target
  link_target="$(readlink "$installs_dir/current")"
  assertEquals 'current symlink should use git-prefixed name' \
    "git-my-branch" "$link_target"
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../../$shunit2RelRoot"
