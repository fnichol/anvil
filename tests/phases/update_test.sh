#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../../vendor/lib/libsh.full.sh"
  . "${SRC:=lib/anvil/phases/update.sh}"

  commonOneTimeSetUp
  root="${0%/*}/../.."
}

setUp() {
  . "lib/anvil/jq.sh"
  . "lib/anvil/config.sh"
  . "lib/anvil/tags.sh"
  . "lib/anvil/convergence.sh"

  commonSetUp

  HOME="$tmpdir/home"
  mkdir -p "$HOME"
}

testUpdateStepsMacosContainsNoExtraManagersByDefault() {
  local config_path="$tmpdir/nonexistent.json"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  # No extra managers and no native package manager to sync
  assertStdoutNull
  assertStderrNull
}

testUpdateStepsMacosContainsExpectedHomebrewStepsIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homebrew"
  }

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "homebrew_sync"
  assertStdoutContains "homebrew"
  assertStdoutContains "homebrew_cask"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testUpdateStepsMacosOrdering() {
  local config_path="$tmpdir/nonexistent.json"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homebrew"
  }

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  local output sync_pos brew_pos cask_pos
  output="$(cat "$stdout")"
  sync_pos="$(echo "$output" | grep -n "^homebrew_sync$" | cut -d: -f1)"
  brew_pos="$(echo "$output" | grep -n "^homebrew$" | cut -d: -f1)"
  cask_pos="$(echo "$output" | grep -n "^homebrew_cask$" | cut -d: -f1)"

  assertTrue 'homebrew_sync before homebrew' "[ $sync_pos -lt $brew_pos ]"
  assertTrue 'homebrew before homebrew_cask' "[ $brew_pos -lt $cask_pos ]"
}

testUpdateStepsArchNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "pacman_sync"
  assertStdoutContains "pacman"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew_sync absent without tags' "grep -q '^homebrew_sync$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull

}

testUpdateStepsArchContainsExpectedStepsIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "aur"
    echo "homeshick"
  }

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "pacman_sync"
  assertStdoutContains "pacman"
  assertStdoutContains "aur"
  assertStdoutContains "homeshick"
  assertFalse 'homebrew_sync absent without tags' "grep -q '^homebrew_sync$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertStderrNull
}

testUpdateStepsArchOrdering() {
  local config_path="$tmpdir/nonexistent.json"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "aur"
  }

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  local output sync_pos pacman_pos aur_pos
  output="$(cat "$stdout")"
  sync_pos="$(echo "$output" | grep -n "^pacman_sync$" | cut -d: -f1)"
  pacman_pos="$(echo "$output" | grep -n "^pacman$" | cut -d: -f1)"
  aur_pos="$(echo "$output" | grep -n "^aur$" | cut -d: -f1)"

  assertTrue 'pacman_sync before pacman' "[ $sync_pos -lt $pacman_pos ]"
  assertTrue 'pacman before aur' "[ $pacman_pos -lt $aur_pos ]"
}

testUpdateStepsCachyosNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "pacman_sync"
  assertStdoutContains "pacman"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew_sync absent without tags' "grep -q '^homebrew_sync$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull

}

testUpdateStepsCachyosContainsExpectedStepsIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "aur"
    echo "homeshick"
  }

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "pacman_sync"
  assertStdoutContains "pacman"
  assertStdoutContains "aur"
  assertStdoutContains "homeshick"
  assertFalse 'homebrew_sync absent without tags' "grep -q '^homebrew_sync$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertStderrNull
}

testUpdateStepsCachyosOrdering() {
  local config_path="$tmpdir/nonexistent.json"
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "aur"
  }

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  local output sync_pos pacman_pos aur_pos
  output="$(cat "$stdout")"
  sync_pos="$(echo "$output" | grep -n "^pacman_sync$" | cut -d: -f1)"
  pacman_pos="$(echo "$output" | grep -n "^pacman$" | cut -d: -f1)"
  aur_pos="$(echo "$output" | grep -n "^aur$" | cut -d: -f1)"

  assertTrue 'pacman_sync before pacman' "[ $sync_pos -lt $pacman_pos ]"
  assertTrue 'pacman before aur' "[ $pacman_pos -lt $aur_pos ]"
}

testUpdateStepsUbuntuNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apt_sync"
  assertStdoutContains "apt"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew_sync absent without tags' "grep -q '^homebrew_sync$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'pacman_sync absent without tags' "grep -q '^pacman_sync$' '$stdout'"
  assertFalse 'pacman absent without tags' "grep -q '^pacman$' '$stdout'"
  assertStderrNull
}

testUpdateStepsUbuntuContainsExpectedStepsIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apt_sync"
  assertStdoutContains "apt"
  assertStdoutContains "homeshick"
  assertStderrNull
}

testUpdateStepsUbuntuOrdering() {
  local config_path="$tmpdir/nonexistent.json"
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  local output sync_pos apt_pos
  output="$(cat "$stdout")"
  sync_pos="$(echo "$output" | grep -n "^apt_sync$" | cut -d: -f1)"
  apt_pos="$(echo "$output" | grep -n "^apt$" | cut -d: -f1)"

  assertTrue 'apt_sync before apt' "[ $sync_pos -lt $apt_pos ]"
}

testUpdateStepsAlpineNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apk_sync"
  assertStdoutContains "apk"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew_sync absent without tags' "grep -q '^homebrew_sync$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'pacman_sync absent without tags' "grep -q '^pacman_sync$' '$stdout'"
  assertFalse 'pacman absent without tags' "grep -q '^pacman$' '$stdout'"
  assertStderrNull
}

testUpdateStepsAlpineContainsExpectedStepsIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apk_sync"
  assertStdoutContains "apk"
  assertStdoutContains "homeshick"
  assertStderrNull
}

testUpdateStepsFreebsdNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="freebsd"
  local version="15.0"
  local kernel="freebsd"
  local arch="x86_64"

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "freebsd_pkg_sync"
  assertStdoutContains "freebsd_pkg"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew_sync absent without tags' "grep -q '^homebrew_sync$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'pacman_sync absent without tags' "grep -q '^pacman_sync$' '$stdout'"
  assertFalse 'pacman absent without tags' "grep -q '^pacman$' '$stdout'"
  assertStderrNull
}

testUpdateStepsFreebsdContainsExpectedSteps() {
  local config_path="$tmpdir/nonexistent.json"
  local os="freebsd"
  local version="15.0"
  local kernel="freebsd"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "freebsd_pkg_sync"
  assertStdoutContains "freebsd_pkg"
  assertStdoutContains "homeshick"
  assertStderrNull
}

testUpdateStepsOpenbsdNativePackageManagersAlwaysPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local os="openbsd"
  local version="7.7"
  local kernel="openbsd"
  local arch="x86_64"

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "openbsd_pkg"
  assertFalse 'openbsd_sync absent without tags' "grep -q '^openbsd_sync$' '$stdout'"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew_sync absent without tags' "grep -q '^homebrew_sync$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homebrew_cask absent without tags' "grep -q '^homebrew_cask$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertFalse 'pacman_sync absent without tags' "grep -q '^pacman_sync$' '$stdout'"
  assertFalse 'pacman absent without tags' "grep -q '^pacman$' '$stdout'"
  assertStderrNull
}

testUpdateStepsOpenbsdContainsExpectedSteps() {
  local config_path="$tmpdir/nonexistent.json"
  local os="openbsd"
  local version="7.7"
  local kernel="openbsd"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  run update_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "openbsd_pkg"
  assertStdoutContains "homeshick"
  # No separate sync step for openbsd (pkg_add -u handles both)
  assertFalse 'openbsd should not have openbsd_pkg_sync' \
    "grep -q 'openbsd_pkg_sync' '$stdout'"
  assertStderrNull
}

testUpdateStepsHomeshickPresentOnAllPlatformsIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  for os in alpine arch bazzite cachyos debian freebsd macos openbsd truenas ubuntu; do
    run update_steps "$root" "$config_path" "$os" "" "" ""

    assertTrue "homeshick missing for $os" \
      "grep -q '^homeshick$' '$stdout'"
  done
}

testUpdateHomeshickNoOpWhenHomeshickNotInstalled() {
  # HOME is set to $tmpdir/home in setUp — no .homesick dir present

  run update_step_homeshick \
    "" "" "" "" "" "" ""

  assertTrue 'should succeed even without homeshick' "$return_status"
  assertStdoutContains "skipping"
}

testUpdateHomeshickPullsWhenInstalled() {
  local homeshick_dir="$HOME/.homesick/repos/homeshick"
  mkdir -p "$homeshick_dir"

  # Create a minimal homeshick.sh stub that defines homeshick()
  printf '#!/bin/sh\nhomeshick() { _homeshick_args="$*"; }\n' \
    >"$homeshick_dir/homeshick.sh"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  run update_step_homeshick \
    "" "" "" "" "" "" ""

  assertTrue 'function failed' "$return_status"
}

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
