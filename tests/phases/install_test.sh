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

  # shellcheck source=lib/anvil/jq.sh
  . "$root/lib/anvil/jq.sh"
  # shellcheck source=lib/anvil/config.sh
  . "$root/lib/anvil/config.sh"
  # shellcheck source=lib/anvil/tags.sh
  . "$root/lib/anvil/tags.sh"
  # shellcheck source=lib/anvil/convergence.sh
  . "$root/lib/anvil/convergence.sh"
}

setUp() {
  commonSetUp

  HOME="$tmpdir/home"
  mkdir -p "$HOME"
}

testInstallStepsIncludesHomeshick() {
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  run install_steps "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "homeshick"
}

testInstallStepsHomeshickPresentOnAllPlatforms() {
  for os in alpine arch bazzite cachyos debian freebsd macos openbsd truenas ubuntu; do
    run install_steps "$os" "" "" ""

    assertTrue "homeshick missing for $os" \
      "grep -q 'homeshick' '$stdout'"
  done
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
