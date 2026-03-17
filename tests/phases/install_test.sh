#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../../vendor/lib/libsh.full.sh"

  . "${SRC:=lib/anvil/phases/install.sh}"

  commonOneTimeSetUp
  root="${0%/*}/../.."
}

setUp() {
  commonSetUp

  # shellcheck source=lib/anvil/jq.sh
  . "lib/anvil/jq.sh"
  # shellcheck source=lib/anvil/config.sh
  . "lib/anvil/config.sh"
  # shellcheck source=lib/anvil/tags.sh
  . "lib/anvil/tags.sh"
  # shellcheck source=lib/anvil/convergence.sh
  . "lib/anvil/convergence.sh"
  # shellcheck source=lib/anvil/discovery.sh
  . "lib/anvil/discovery.sh"

  HOME="$tmpdir/home"
  mkdir -p "$HOME"
}

testInstallStepsNoExtraManagersByDefault() {
  local config_path="$tmpdir/nonexistent.json"

  for os in alpine arch cachyos debian freebsd macos openbsd ubuntu; do
    run install_steps "$root" "$config_path" "$os" "" "" ""

    assertFalse "homeshick absent without tags ($os)" \
      "grep -q '^homeshick$' '$stdout'"
    assertFalse "homebrew absent without tags ($os)" \
      "grep -q '^homebrew$' '$stdout'"
  done
}

testInstallStepsEmitsHomeshickIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  run install_steps "$root" "$config_path" "arch" "" "" ""

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "homeshick"
}

testInstallStepsEmitsHomebrewOnLinuxIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homebrew"
  }

  run install_steps "$root" "$config_path" "cachyos" "" "" ""

  assertStdoutContains "homebrew"
  assertFalse 'no cask on linux' "grep -q '^homebrew_cask$' '$stdout'"
}

testInstallStepsEmitsHomebrewCaskOnMacosIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homebrew"
  }

  run install_steps "$root" "$config_path" "macos" "" "" ""

  assertStdoutContains "homebrew"
  assertStdoutContains "homebrew_cask"
}

testInstallStepsEmitsHomeshickOnAllPlatformsIfDefined() {
  local config_path="$tmpdir/nonexistent.json"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  for os in alpine arch bazzite cachyos debian freebsd macos openbsd truenas ubuntu; do
    run install_steps "$root" "$config_path" "$os" "" "" ""

    assertTrue "homeshick missing for $os" \
      "grep -q 'homeshick' '$stdout'"
  done
}

testInstallStepsEmitsAlpineNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  run install_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apk"
  assertFalse 'apt absent without tags' "grep -q '^apt$' '$stdout'"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'freebsd_pkg absent without tags' "grep -q '^freebsd_pkg$' '$stdout'"
  assertFalse 'openbsd_pkg absent without tags' "grep -q '^openbsd_pkg$' '$stdout'"
  assertFalse 'pacman absent without tags' "grep -q '^pacman$' '$stdout'"
}

testInstallStepsEmitsArchNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  run install_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "pacman"
  assertFalse 'apk absent without tags' "grep -q '^apk$' '$stdout'"
  assertFalse 'apt absent without tags' "grep -q '^apt$' '$stdout'"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'freebsd_pkg absent without tags' "grep -q '^freebsd_pkg$' '$stdout'"
  assertFalse 'openbsd_pkg absent without tags' "grep -q '^openbsd_pkg$' '$stdout'"
}

testInstallStepsEmitsCachyosNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  run install_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "pacman"
  assertFalse 'apk absent without tags' "grep -q '^apk$' '$stdout'"
  assertFalse 'apt absent without tags' "grep -q '^apt$' '$stdout'"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'freebsd_pkg absent without tags' "grep -q '^freebsd_pkg$' '$stdout'"
  assertFalse 'openbsd_pkg absent without tags' "grep -q '^openbsd_pkg$' '$stdout'"
}

testInstallStepsEmitsDebianNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="debian"
  local version="12.13"
  local kernel="linux"
  local arch="x86_64"

  run install_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apt"
  assertFalse 'apk absent without tags' "grep -q '^apk$' '$stdout'"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'freebsd_pkg absent without tags' "grep -q '^freebsd_pkg$' '$stdout'"
  assertFalse 'openbsd_pkg absent without tags' "grep -q '^openbsd_pkg$' '$stdout'"
  assertFalse 'pacman absent without tags' "grep -q '^pacman$' '$stdout'"
}

testInstallStepsEmitsFreebsdNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="freebsd"
  local version="15.0"
  local kernel="freebsd"
  local arch="x86_64"

  run install_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "freebsd_pkg"
  assertFalse 'apk absent without tags' "grep -q '^apk$' '$stdout'"
  assertFalse 'apt absent without tags' "grep -q '^apt$' '$stdout'"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'openbsd_pkg absent without tags' "grep -q '^openbsd_pkg$' '$stdout'"
  assertFalse 'pacman absent without tags' "grep -q '^pacman$' '$stdout'"
}

testInstallStepsEmitsOpenbsdNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="openbsd"
  local version="7.7"
  local kernel="openbsd"
  local arch="x86_64"

  run install_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "openbsd_pkg"
  assertFalse 'apk absent without tags' "grep -q '^apk$' '$stdout'"
  assertFalse 'apt absent without tags' "grep -q '^apt$' '$stdout'"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'freebsd_pkg absent without tags' "grep -q '^freebsd_pkg$' '$stdout'"
  assertFalse 'pacman absent without tags' "grep -q '^pacman$' '$stdout'"
}

testInstallStepsEmitsUbuntuNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  run install_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apt"
  assertFalse 'apk absent without tags' "grep -q '^apk$' '$stdout'"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'freebsd_pkg absent without tags' "grep -q '^freebsd_pkg$' '$stdout'"
  assertFalse 'openbsd_pkg absent without tags' "grep -q '^openbsd_pkg$' '$stdout'"
  assertFalse 'pacman absent without tags' "grep -q '^pacman$' '$stdout'"
}

testInstallStepPackagesNoOpWhenNoTags() {
  local config_path="$tmpdir/nonexistent.json"
  local os="arch"
  local arch="x86_64"

  local package_type="pacman"

  # Stub config_read_tags to return empty
  # shellcheck disable=SC2329
  config_read_tags() { :; }

  _dispatched=""
  # shellcheck disable=SC2329
  _install_packages_pacman() { _dispatched="yes"; }

  run _install_step_packages \
    "$root" "$config_path" "$os" "$arch" "$package_type"

  assertTrue 'function failed' "$return_status"
  assertEquals 'should not dispatch when no tags' "" "${_dispatched:-}"
}

testInstallStepPackagesNoOpWhenAlreadyConverged() {
  local config_path="$tmpdir/nonexistent.json"
  local os="arch"
  local arch="x86_64"

  local package_type="pacman"

  # shellcheck disable=SC2329
  config_read_tags() { echo "base"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "base"; }
  # shellcheck disable=SC2329
  desired_packages() { printf 'git\ncurl\n'; }
  # shellcheck disable=SC2329
  discover_installed_packages() { printf 'git\ncurl\n'; }

  _dispatched=""
  # shellcheck disable=SC2329
  _install_packages_pacman() { _dispatched="yes"; }

  run _install_step_packages \
    "$root" "$config_path" "$os" "$arch" "$package_type"

  assertTrue 'function failed' "$return_status"
  assertEquals 'should not dispatch when converged' "" "${_dispatched:-}"
  assertStdoutContains "already in desired state"
}

testInstallStepPackagesDispatchesDeltaToInstaller() {
  local config_path="$tmpdir/nonexistent.json"
  local os="arch"
  local arch="x86_64"

  local package_type="pacman"

  # shellcheck disable=SC2329
  config_read_tags() { echo "base"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "base"; }
  # shellcheck disable=SC2329
  desired_packages() { printf 'git\ncurl\nvim\n'; }
  # shellcheck disable=SC2329
  discover_installed_packages() { printf 'git\ncurl\n'; }

  _dispatched_packages=""
  # shellcheck disable=SC2329
  _install_packages_pacman() { _dispatched_packages="$1"; }

  run _install_step_packages \
    "$root" "$config_path" "$os" "$arch" "$package_type"

  assertTrue 'function failed' "$return_status"
  assertTrue 'should dispatch vim' \
    "echo '$_dispatched_packages' | grep -q '^vim$'"
  assertFalse 'should not dispatch already-installed git' \
    "echo '$_dispatched_packages' | grep -q '^git$'"
}

testInstallStepPackagesDispatchesToCorrectFunction() {
  local config_path="$tmpdir/nonexistent.json"
  local os="macos"
  local arch="aarch64"

  local package_type="homebrew"

  # shellcheck disable=SC2329
  config_read_tags() { echo "base"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "base"; }
  # shellcheck disable=SC2329
  desired_packages() { printf 'bat\n'; }
  # shellcheck disable=SC2329
  discover_installed_packages() { :; }

  _brew_called=""
  _pacman_called=""
  # shellcheck disable=SC2329
  _install_packages_homebrew() { _brew_called="yes"; }
  # shellcheck disable=SC2329
  _install_packages_pacman() { _pacman_called="yes"; }

  run _install_step_packages \
    "$root" "$config_path" "$os" "$arch" "$package_type"

  assertTrue 'function failed' "$return_status"
  assertEquals 'homebrew should be called' "yes" "${_brew_called:-}"
  assertEquals 'pacman should not be called' "" "${_pacman_called:-}"
}

testInstallHomeshickNoOpWhenNoDesiredCastles() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # Stub desired_packages to return empty
  # shellcheck disable=SC2329
  desired_packages() { :; }
  # homeshick must not be called
  # shellcheck disable=SC2329
  homeshick() { return 1; }

  run install_step_homeshick \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed with no castles' "$return_status"
}

testInstallHomeshickSkipsCastleAlreadyCloned() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  mkdir -p "$HOME/.homesick/repos/dotneovim"
  mkdir -p "$HOME/.homesick/repos/homeshick"

  # shellcheck disable=SC2329
  desired_packages() { printf 'fnichol/dotneovim\n'; }
  # shellcheck disable=SC2329
  config_read_tags() { echo "neovim"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "neovim"; }

  _homeshick_called=""
  # shellcheck disable=SC2329
  homeshick() { _homeshick_called="yes"; }

  run install_step_homeshick \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertNotEquals 'homeshick clone was called for already-present castle' \
    "yes" "${_homeshick_called:-}"
}

testInstallHomeshickClonesNewCastle() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="aarch64"

  mkdir -p "$HOME/.homesick/repos/homeshick"
  touch "$HOME/.homesick/repos/homeshick/homeshick.sh"

  # shellcheck disable=SC2329
  desired_packages() { printf 'fnichol/dotneovim\n'; }
  # shellcheck disable=SC2329
  config_read_tags() { echo "neovim"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "neovim"; }

  _cloned_castle=""
  # shellcheck disable=SC2329
  homeshick() {
    case "$1" in
      clone)
        _cloned_castle="$3"
        ;;
    esac
  }

  run install_step_homeshick \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'wrong castle cloned' "fnichol/dotneovim" "$_cloned_castle"
}

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
