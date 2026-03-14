#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../../vendor/lib/libsh.full.sh"
  . "${SRC:=lib/anvil/phases/bootstrap.sh}"

  commonOneTimeSetUp
  root="${0%/*}/../.."
}

setUp() {
  . "lib/anvil/jq.sh"
  . "lib/anvil/config.sh"
  . "lib/anvil/tags.sh"
  . "lib/anvil/convergence.sh"

  commonSetUp
}

testBootstrapStepsMacosNoExtraManagersWithoutTags() {
  local config_path="$tmpdir/nonexistent.json"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() { :; }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsMacosEmitsHomebrewWhenTagsDeclareIt() {
  local config_path="$tmpdir/nonexistent.json"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
    echo "homebrew"
    echo "homeshick"
  }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "homebrew"
  assertStdoutContains "homeshick"
  assertStdoutContains "bashrc"
  assertStderrNull
}

testBootstrapStepsOrderingHomebrewBeforeBashrcBeforeHomeshick() {
  local config_path="$tmpdir/nonexistent.json"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
    echo "homebrew"
    echo "homeshick"
  }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  local output homebrew_pos bashrc_pos homeshick_pos
  output="$(cat "$stdout")"
  homebrew_pos="$(echo "$output" | grep -n "^homebrew$" | cut -d: -f1)"
  bashrc_pos="$(echo "$output" | grep -n "^bashrc$" | cut -d: -f1)"
  homeshick_pos="$(echo "$output" | grep -n "^homeshick$" | cut -d: -f1)"

  assertTrue 'homebrew before bashrc' "[ $homebrew_pos -lt $bashrc_pos ]"
  assertTrue 'bashrc before homeshick' "[ $bashrc_pos -lt $homeshick_pos ]"
}

testBootstrapStepsArchNoExtraManagersWithoutTags() {
  local config_path="$tmpdir/nonexistent.json"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsArchContainsAurIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "aur"
  }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "aur"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsArchContainsAurBeforeBashrc() {
  local config_path="$tmpdir/nonexistent.json"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "aur"
    echo "bashrc"
    echo "homeshick"
  }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "aur"
  assertStdoutContains "bashrc"
  assertStdoutContains "homeshick"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"

  local output aur_pos bashrc_pos
  output="$(cat "$stdout")"
  aur_pos="$(echo "$output" | grep -n "^aur$" | cut -d: -f1)"
  bashrc_pos="$(echo "$output" | grep -n "^bashrc$" | cut -d: -f1)"

  assertTrue 'aur before bashrc' "[ $aur_pos -lt $bashrc_pos ]"
}

testBootstrapStepsCachyosNoExtraManagersWithoutTags() {
  local config_path="$tmpdir/nonexistent.json"
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsCachyosContainsAurIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "aur"
  }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "aur"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsCachyosContainsAurBeforeBashrc() {
  local config_path="$tmpdir/nonexistent.json"
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "aur"
    echo "bashrc"
    echo "homeshick"
  }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "aur"
  assertStdoutContains "bashrc"
  assertStdoutContains "homeshick"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"

  local output aur_pos bashrc_pos
  output="$(cat "$stdout")"
  aur_pos="$(echo "$output" | grep -n "^aur$" | cut -d: -f1)"
  bashrc_pos="$(echo "$output" | grep -n "^bashrc$" | cut -d: -f1)"

  assertTrue 'aur before bashrc' "[ $aur_pos -lt $bashrc_pos ]"
}

testBootstrapStepsUbuntuNoExtraManagersWithoutTags() {
  local config_path="$tmpdir/nonexistent.json"
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsUbuntuHasBashrcAndHomeshickIfDeclared() {
  local config_path="$tmpdir/nonexistent.json"
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
    echo "homeshick"
  }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "bashrc"
  assertStdoutContains "homeshick"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
}

testBootstrapStepsUbuntuHasNoPackageManagerStep() {
  local config_path="$tmpdir/nonexistent.json"
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no apt step' "grep -q '^apt$' '$stdout'"
}

testBootstrapStepsAlpineNoExtraManagersWithoutTags() {
  local config_path="$tmpdir/nonexistent.json"
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsAlpineHasBashrcAndHomeshickIfDefined() {
  local config_path="$tmpdir/nonexistent.json"
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
    echo "homeshick"
  }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "bashrc"
  assertStdoutContains "homeshick"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
}

testBootstrapStepsFreebsdNoExtraManagersWithoutTags() {
  local config_path="$tmpdir/nonexistent.json"
  local os="freebsd"
  local version="15.0"
  local kernel="freebsd"
  local arch="x86_64"

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsFreebsdHasBashrcAndHomeshickIfDefined() {
  local config_path="$tmpdir/nonexistent.json"
  local os="freebsd"
  local version="15.0"
  local kernel="freebsd"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
    echo "homeshick"
  }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "bashrc"
  assertStdoutContains "homeshick"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
}

testBootstrapStepsOpenbsdNoExtraManagersWithoutTags() {
  local config_path="$tmpdir/nonexistent.json"
  local os="openbsd"
  local version="7.7"
  local kernel="openbsd"
  local arch="x86_64"

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsOpenbsdHasBashrcAndHomeshickIfDefined() {
  local config_path="$tmpdir/nonexistent.json"
  local os="openbsd"
  local version="7.7"
  local kernel="openbsd"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
    echo "homeshick"
  }

  run bootstrap_steps "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "bashrc"
  assertStdoutContains "homeshick"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
}

testBashrcSkipsIfAlreadyInstalled() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  HOME="$tmpdir/home"

  mkdir -p "$tmpdir/.bash"
  touch "$tmpdir/.bash/bashrc"

  # If download function is invoked, the test must fail
  # shellcheck disable=SC2329
  download() { return 1; }

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
  }

  run bootstrap_step_bashrc \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed (idempotent)' "$return_status"
}

testBashrcDownloadsAndInvokesInstallerWhenNotPresent() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  HOME="$tmpdir/home"

  _dl_url=""
  _dl_script=""
  # Mock the download function to return a simulated installer script
  # shellcheck disable=SC2329
  download() {
    _dl_url="$1"
    _dl_script="$2"

    cat <<-'EOF' >"$_dl_script"
	# Simulate installer creating the output file
        dst="$HOME/.bash"
        echo "Installing local bashrc to: $dst"
	mkdir -p "$dst"
	touch "$dst/bashrc"
	EOF
  }

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
  }

  run bootstrap_step_bashrc \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertTrue 'curl URL contains bashrc' \
    "echo '$_dl_url' | grep -q 'fnichol/bashrc'"
  assertTrue 'stub installation failed to create file' \
    "[ -f '$HOME/.bash/bashrc' ]"
}

testHomeshickSkipsIfAlreadyInstalled() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  HOME="$tmpdir/home"

  mkdir -p "$HOME/.homesick/repos/homeshick"

  # git must not be called
  # shellcheck disable=SC2329
  git() { return 1; }

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  run bootstrap_step_homeshick \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed (idempotent)' "$return_status"
}

testHomeshickClonesRepo() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  HOME="$tmpdir/home"

  _git_cloned=""
  # shellcheck disable=SC2329
  git() {
    case "$1" in
      clone)
        _git_cloned="yes"
        mkdir -p "$HOME/.homesick/repos/homeshick"
        ;;
    esac
  }
  # shellcheck disable=SC2329
  indent() { "$@"; }
  # shellcheck disable=SC2329
  check_cmd() { return 0; }
  # shellcheck disable=SC2329
  as_root() { "$@"; }

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  run bootstrap_step_homeshick \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'git clone not called' "yes" "$_git_cloned"
}

testHomeshickWritesDropinWhenBashDExists() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  HOME="$tmpdir/home"

  mkdir -p "$HOME/.bash.d"

  # shellcheck disable=SC2329
  git() {
    case "$1" in
      clone)
        mkdir -p "$HOME/.homesick/repos/homeshick"
        ;;
    esac
  }
  # shellcheck disable=SC2329
  indent() { "$@"; }
  # shellcheck disable=SC2329
  check_cmd() { return 0; }

  run bootstrap_step_homeshick \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertTrue 'dropin file created' "[ -f '$HOME/.bash.d/homeshick.bash' ]"
  assertTrue 'dropin contains source line' \
    "grep -q 'homeshick.sh' '$HOME/.bash.d/homeshick.bash'"
}

testHomeshickAppendsToBashrcWhenNoBashD() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  HOME="$tmpdir/home"

  mkdir -p "$HOME"

  touch "$HOME/.bashrc"

  # shellcheck disable=SC2329
  git() {
    case "$1" in
      clone)
        mkdir -p "$HOME/.homesick/repos/homeshick"
        ;;
    esac
  }
  # shellcheck disable=SC2329
  indent() { "$@"; }
  # shellcheck disable=SC2329
  check_cmd() { return 0; }

  run bootstrap_step_homeshick \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertTrue '.bashrc contains source line' \
    "grep -q 'homeshick.sh' '$HOME/.bashrc'"
}

testHomeshickDropinIsIdempotent() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  HOME="$tmpdir/home"

  mkdir -p "$HOME/.bash.d"
  # Pre-existing dropin file
  # shellcheck disable=SC2016
  printf 'source "$HOME/.homesick/repos/homeshick/homeshick.sh"\n' \
    >"$HOME/.bash.d/homeshick.bash"
  mkdir -p "$HOME/.homesick/repos/homeshick"

  run bootstrap_step_homeshick \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals \
    'dropin written more than once' \
    "1" \
    "$(grep -c 'homeshick.sh' "$HOME/.bash.d/homeshick.bash")"
}

testHomebrewSkipsIfAlreadyInstalled() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  check_cmd() {
    case "$1" in
      brew | git)
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  }
  # If download function is invoked, the test must fail
  # shellcheck disable=SC2329
  download() { return 1; }

  run bootstrap_step_homebrew \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed (idempotent)' "$return_status"
}

testHomebrewSetsNoninteractiveWhenInstalling() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  indent() { "$@"; }
  # shellcheck disable=SC2329
  check_cmd() {
    case "$1" in
      brew) # brew no present
        return 1
        ;;
      *)
        return 0
        ;;
    esac
  }
  # shellcheck disable=SC2329
  need_cmd() { :; }

  _dl_url=""
  _dl_script=""
  _noninteractive_set=""
  # Mock the download function to return a simulated installer script
  # shellcheck disable=SC2329
  download() {
    _dl_url="$1"
    _dl_script="$2"

    cat <<-'EOF' >"$_dl_script"
	# Emit a tiny script that records the env variable
	[ -n "$NONINTERACTIVE" ] && echo "noninteractive_set"
	EOF
  }

  # Capture bash execution output (remember: bash might not be present on
  # system performing tests)
  #
  # shellcheck disable=SC2329
  bash() {
    local script
    script="$(cat /dev/stdin)"
    output="$(eval "$script")"
    if echo "$output" | grep -q "noninteractive_set"; then
      _noninteractive_set="yes"
    fi
  }

  run bootstrap_step_homebrew \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed' "$return_status"
  assertStdoutContains 'noninteractive_set'
}

testAurSkipsIfParuAlreadyInstalled() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  check_cmd() {
    case "$1" in
      paru) return 0 ;;
      *) return 1 ;;
    esac
  }
  # git must not be called
  # shellcheck disable=SC2329
  git() { return 1; }

  run bootstrap_step_aur \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed (idempotent)' "$return_status"
}

testAurOnArchInstallsGitIfMissing() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  indent() { "$@"; }
  # shellcheck disable=SC2329
  check_cmd() {
    case "$1" in
      git | paru) # paru and git both missing
        return 1
        ;;
      *)
        return 0
        ;;
    esac
  }

  _pacman_args=""
  # shellcheck disable=SC2329
  as_root() {
    case "$*" in
      *pacman*)
        _pacman_args="$_pacman_args\n$*"
        ;;
    esac
  }
  # shellcheck disable=SC2329
  git() { :; }
  # shellcheck disable=SC2329
  makepkg() { :; }
  # shellcheck disable=SC2329
  sudo() { :; }

  run bootstrap_step_aur \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'pacman git install was called' \
    "echo '$_pacman_args' | grep -q 'git'"
}

testAurOnArchClonesParu() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  indent() { "$@"; }
  # shellcheck disable=SC2329
  check_cmd() { return 1; } # paru missing, git missing

  _git_url=""
  # shellcheck disable=SC2329
  git() {
    case "$1" in
      clone)
        _git_url="$2"
        ;;
    esac
  }
  # shellcheck disable=SC2329
  as_root() { :; }
  # shellcheck disable=SC2329
  chown() { :; }
  # shellcheck disable=SC2329
  makepkg() { :; }

  run bootstrap_step_aur \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'paru URL used' \
    "echo '$_git_url' | grep -q 'paru'"
}

testAurOnCachyOsInstallsParuBin() {
  local config_path="$tmpdir/nonexistent.json"
  local hostname="myhost.local"
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  indent() { "$@"; }
  # shellcheck disable=SC2329
  check_cmd() {
    case "$1" in
      paru) # paru missing
        return 1
        ;;
      *)
        return 0
        ;;
    esac
  }

  _pacman_args=""
  # shellcheck disable=SC2329
  as_root() {
    case "$*" in
      *pacman*)
        _pacman_args="$_pacman_args\n$*"
        ;;
    esac
  }
  # shellcheck disable=SC2329
  git() { return 1; }
  # shellcheck disable=SC2329
  makepkg() { return 1; }

  run bootstrap_step_aur \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'pacman paru-bin install was called' \
    "echo '$_pacman_args' | grep -q 'paru-bin'"
}

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
