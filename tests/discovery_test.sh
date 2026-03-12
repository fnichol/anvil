#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../vendor/lib/libsh.full.sh"
  . "${SRC:=lib/anvil/discovery.sh}"

  commonOneTimeSetUp
}

setUp() {
  commonSetUp
  mkdir -p "$isolated_path"
}

testDiscoverInstalledAlpineApkUsesApk() {
  # Stub out `pacman -Qm` which reports locally installed packages
  cat <<-'EOF' >"$isolated_path/apk"
	#!/bin/sh
	case "$1" in
	  info)
	    echo "musl"
	    echo "zlib"
	    ;;
	  *)
	    exit 1
	    ;;
	esac
	EOF
  chmod +x "$isolated_path/apk"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "alpine" "apk"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "musl"
  assertStdoutContains "zlib"
  assertStderrNull
}

testDiscoverInstalledArchAurUsesPacman() {
  # Stub out `pacman -Qm` which reports locally installed packages
  cat <<-'EOF' >"$isolated_path/pacman"
	#!/bin/sh
	case "$*" in
	  *--foreign*)
	    echo "git"
	    echo "curl"
	    ;;
	  *)
	    exit 1
	    ;;
	esac
	EOF
  chmod +x "$isolated_path/pacman"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "arch" "aur"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "git"
  assertStdoutContains "curl"
  assertStderrNull
}

testDiscoverInstalledArchPacmanUsesPacman() {
  # Stub out `pacman`
  cat <<-'EOF' >"$isolated_path/pacman"
	#!/bin/sh
	echo "xz"
	echo "zlib"
	EOF
  chmod +x "$isolated_path/pacman"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "arch" "pacman"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "xz"
  assertStdoutContains "zlib"
  assertStderrNull
}

testDiscoverInstalledBazziteDnfUsesDnf() {
  # Stub out `dnf`
  cat <<-'EOF' >"$isolated_path/dnf"
	#!/bin/sh
	echo "xz.x86_64"
	echo "zlib.x86_64"
	EOF
  chmod +x "$isolated_path/dnf"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "bazzite" "dnf"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "xz"
  assertStdoutContains "zlib"
  assertStderrNull
}

testDiscoverInstalledCachyosAurUsesPacman() {
  # Stub out `pacman -Qm` which reports locally installed packages
  cat <<-'EOF' >"$isolated_path/pacman"
	#!/bin/sh
	case "$*" in
	  *--foreign*)
	    echo "vim"
	    ;;
	  *)
	    exit 1
	    ;;
	esac
	EOF
  chmod +x "$isolated_path/pacman"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "cachyos" "aur"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "vim"
  assertStderrNull
}

testDiscoverInstalleCachyosPacmanUsesPacman() {
  # Stub out `pacman`
  cat <<-'EOF' >"$isolated_path/pacman"
	#!/bin/sh
	echo "xz"
	echo "zlib"
	EOF
  chmod +x "$isolated_path/pacman"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "cachyos" "pacman"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "xz"
  assertStdoutContains "zlib"
  assertStderrNull
}

testDiscoverInstalledDebianAptUsesDpkgQuery() {
  # Stub out `dpkg-query`
  cat <<-'EOF' >"$isolated_path/dpkg-query"
	#!/bin/sh
	echo "git"
	EOF
  chmod +x "$isolated_path/dpkg-query"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "debian" "apt"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "git"
  assertStderrNull
}

testDiscoverInstalledFreebsdPkgUsesPkg() {
  # Stub out `pkg`
  cat <<-'EOF' >"$isolated_path/pkg"
	#!/bin/sh
	case "$1" in
	  info)
	    echo "bash"
	    echo "vim"
	    ;;
	  *)
	    exit 1
	    ;;
	esac
	EOF
  chmod +x "$isolated_path/pkg"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "freebsd" "freebsd_pkg"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "bash"
  assertStdoutContains "vim"
  assertStderrNull
}

testDiscoverInstalledMacosHomebrewUsesBrew() {
  # Stub out `brew`
  cat <<-'EOF' >"$isolated_path/brew"
	#!/bin/sh
	case "$*" in
	  *--formula*)
	    echo "neovim"
	    echo "starship"
	    ;;
	  *)
	    exit 1
	    ;;
	esac
	EOF
  chmod +x "$isolated_path/brew"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "macos" "homebrew"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "neovim"
  assertStdoutContains "starship"
  assertStderrNull
}

testDiscoverInstalledMacosHomebrewCaskUsesBrew() {
  # Stub out `brew`
  cat <<-'EOF' >"$isolated_path/brew"
	#!/bin/sh
	case "$*" in
	  *--cask*)
	    echo "areospace"
	    ;;
	  *)
	    exit 1
	    ;;
	esac
	EOF
  chmod +x "$isolated_path/brew"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "macos" "homebrew_cask"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "areospace"
  assertStderrNull
}

testDiscoverInstalledOpenbsdPkgAddUsesPkgInfo() {
  # Stub out `pkg_info`
  cat <<-'EOF' >"$isolated_path/pkg_info"
	#!/bin/sh
	case "$*" in
	  *-q*)
	    echo "rsync"
	    echo "zsh"
	    ;;
	  *)
	    exit 1
	    ;;
	esac
	EOF
  chmod +x "$isolated_path/pkg_info"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "openbsd" "openbsd_pkg"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "rsync"
  assertStdoutContains "zsh"
  assertStderrNull
}

testDiscoverInstalledTruenasAptUsesDpkgQuery() {
  # Stub out `dpkg-query`
  cat <<-'EOF' >"$isolated_path/dpkg-query"
	#!/bin/sh
	echo "udev"
	EOF
  chmod +x "$isolated_path/dpkg-query"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "truenas" "apt"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "udev"
  assertStderrNull
}

testDiscoverInstalledUbuntuAptUsesDpkgQuery() {
  # Stub out `dpkg-query`
  cat <<-'EOF' >"$isolated_path/dpkg-query"
	#!/bin/sh
	echo "bash"
	echo "curl"
	EOF
  chmod +x "$isolated_path/dpkg-query"
  PATH="$isolated_path:$PATH"

  run discover_installed_packages "ubuntu" "apt"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "bash"
  assertStdoutContains "curl"
  assertStderrNull
}

shell_compat "$0"

. "$shunit2"
