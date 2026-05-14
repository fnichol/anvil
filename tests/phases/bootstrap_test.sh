#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
  . "$SRC_ROOT/lib/anvil/config.sh"
  . "$SRC_ROOT/lib/anvil/modules.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/phases/bootstrap.sh}"

  config_file="$(config_path)"
  data_home="$(modules_data_home)"
  mod_path="$(module_path_for "$data_home" default)"
}

# Helper: writes a config with the given tags
_writeConfigWithTags() {
  local tags_csv="$1"

  writeConfigFile <<-EOF
	{
	  "modules":[
	    {"name":"default","url":"https://example.com/default.git"}
	  ],
	  "tags": [$(echo "$tags_csv" | sed 's/,/","/g;s/^/"/;s/$/"/')]
	}
	EOF
}

# Helper: writes a tag JSON declaring a bootsteap hook for all os/arch
_writeTagWithBootstrapHook() {
  local mod_path="$1"
  local tag_name="$2"
  local hook_name="$3"

  mkdir -p "$mod_path/tags"

  cat <<-EOF >"$mod_path/tags/${tag_name}.json"
	{
	  "name": "${tag_name}",
	  "depends_on": [],
	  "hooks": {
	    "bootstrap": {
	      "all": { "all": ["${hook_name}"] }
	    }
	  }
	}
	EOF
}

testBootstrapStepsMacosNoExtraManagersWithoutTags() {
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() { :; }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsMacosEmitsHomebrewWhenTagsDeclareIt() {
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

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "homebrew"
  assertStdoutContains "homeshick"
  assertStdoutContains "bashrc"
  assertStderrNull
}

testBootstrapStepsOrderingHomebrewBeforeBashrcBeforeHomeshick() {
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

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  local output homebrew_pos bashrc_pos homeshick_pos
  output="$(cat "$stdout")"
  homebrew_pos="$(echo "$output" | grep -n "^homebrew$" | cut -d: -f1)"
  bashrc_pos="$(echo "$output" | grep -n "^bashrc$" | cut -d: -f1)"
  homeshick_pos="$(echo "$output" | grep -n "^homeshick$" | cut -d: -f1)"

  assertTrue 'homebrew before bashrc' "[ $homebrew_pos -lt $bashrc_pos ]"
  assertTrue 'bashrc before homeshick' "[ $bashrc_pos -lt $homeshick_pos ]"
}

testBootstrapStepsEmitsMiseOnMacosWhenDeclared() {
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() { echo "mise"; }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "mise"
  assertStderrNull
}

testBootstrapStepsArchNoExtraManagersWithoutTags() {
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsArchContainsAurIfDeclared() {
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "aur"
  }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "aur"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsArchContainsAurBeforeBashrc() {
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

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

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

testBootstrapStepsArchContainsMiseIfDeclared() {
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "mise"
  }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "mise"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsCachyosNoExtraManagersWithoutTags() {
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsCachyosContainsAurIfDeclared() {
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "aur"
  }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "aur"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsCachyosContainsAurBeforeBashrc() {
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

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

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

testBootstrapStepsCachyosContainsMiseIfDeclared() {
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "mise"
  }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "mise"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsUbuntuNoExtraManagersWithoutTags() {
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsUbuntuHasBashrcAndHomeshickIfDeclared() {
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
    echo "homeshick"
  }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "bashrc"
  assertStdoutContains "homeshick"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
}

testBootstrapStepsUbuntuHasNoPackageManagerStep() {
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no apt step' "grep -q '^apt$' '$stdout'"
}

testBootstrapStepsUbuntuContainsMiseIfDeclared() {
  local os="ubuntu"
  local version="25.10"
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "mise"
  }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "mise"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsAlpineNoExtraManagersWithoutTags() {
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsAlpineHasBashrcAndHomeshickIfDefined() {
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
    echo "homeshick"
  }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "bashrc"
  assertStdoutContains "homeshick"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
}

testBootstrapStepsAlpineContainsMiseIfDeclared() {
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "mise"
  }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "mise"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsFreebsdNoExtraManagersWithoutTags() {
  local os="freebsd"
  local version="15.0"
  local kernel="freebsd"
  local arch="x86_64"

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsFreebsdHasBashrcAndHomeshickIfDefined() {
  local os="freebsd"
  local version="15.0"
  local kernel="freebsd"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
    echo "homeshick"
  }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "bashrc"
  assertStdoutContains "homeshick"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
}

testBootstrapStepsOmitsMiseOnFreebsd() {
  local os="freebsd"
  local version="14.0"
  local kernel="freebsd"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() { echo "mise"; }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'mise absent on freebsd' "grep -q '^mise$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsOpenbsdNoExtraManagersWithoutTags() {
  local os="openbsd"
  local version="7.7"
  local kernel="openbsd"
  local arch="x86_64"

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'bashrc absent without tags' "grep -q '^bashrc$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
  assertFalse 'homeshick absent without tags' "grep -q '^homeshick$' '$stdout'"
  assertStderrNull
}

testBootstrapStepsOpenbsdHasBashrcAndHomeshickIfDefined() {
  local os="openbsd"
  local version="7.7"
  local kernel="openbsd"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "bashrc"
    echo "homeshick"
  }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "bashrc"
  assertStdoutContains "homeshick"
  assertFalse 'aur absent without tags' "grep -q '^aur$' '$stdout'"
  assertFalse 'homebrew absent without tags' "grep -q '^homebrew$' '$stdout'"
}

testBootstrapStepsOmitsMiseOnOpenbsd() {
  local os="openbsd"
  local version="7.4"
  local kernel="openbsd"
  local arch="x86_64"

  # shellcheck disable=SC2329
  _steps_extra_package_managers() { echo "mise"; }

  run bootstrap_steps \
    "$config_file" "$data_home" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertFalse 'mise absent on openbsd' "grep -q '^mise$' '$stdout'"
  assertStderrNull
}

testBoostrapStepsEmitsHookStepWhenTagDeclaresIt() {
  mkdir -p "$mod_path/hooks/bootstrap"
  touch "$mod_path/hooks/bootstrap/010-neat-repo.sh"
  _writeTagWithBootstrapHook "$mod_path" "myconf" "neat-repo"

  _writeConfigWithTags "myconf"

  run bootstrap_steps \
    "$config_file" "$data_home" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "hook_neat_repo"
}

testConfigureStepsDoesNotEmitHookWhenOsDoesNotMatch() {
  mkdir -p "$mod_path/hooks/bootstrap"
  touch "$mod_path/hooks/bootstrap/010-neat-repo.sh"

  mkdir -p "$mod_path/tags"
  cat <<-EOF >"$mod_path/tags/myconf.json"
	{
	  "name": "myconf",
	  "depends_on": [],
	  "hooks": {
	    "bootstrap": {
	      "arch": { "all": ["neat-repo"] }
	    }
	  }
	}
	EOF

  _writeConfigWithTags "myconf"

  run bootstrap_steps \
    "$config_file" "$data_home" "macos" "" "darwin" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertFalse 'no hook steps expected for non-matching os' \
    "grep -q '^hook_' '$stdout'"
}

testConfigureStepsEmitsMultipleHooksInNumericOrder() {
  mkdir -p "$mod_path/hooks/bootstrap"
  touch "$mod_path/hooks/bootstrap/020-banana-peel.sh"
  touch "$mod_path/hooks/bootstrap/010-orange-rind.sh"

  mkdir -p "$mod_path/tags"
  cat <<-EOF >"$mod_path/tags/myconf.json"
	{
	  "name": "myconf",
	  "depends_on": [],
	  "hooks": {
	    "bootstrap": {
	      "all": { "all": ["orange-rind", "banana-peel"] }
	    }
	  }
	}
	EOF

  _writeConfigWithTags "myconf"

  run bootstrap_steps \
    "$config_file" "$data_home" "arch" "" "linux" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertEquals 'wrong order' \
    "$(printf 'hook_orange_rind\nhook_banana_peel')" \
    "$(grep '^hook_' "$stdout")"
}

testBashrcSkipsIfAlreadyInstalled() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed (idempotent)' "$return_status"
}

testBashrcDownloadsAndInvokesInstallerWhenNotPresent() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertTrue 'curl URL contains bashrc' \
    "echo '$_dl_url' | grep -q 'fnichol/bashrc'"
  assertTrue 'stub installation failed to create file' \
    "[ -f '$HOME/.bash/bashrc' ]"
}

testHomeshickSkipsIfAlreadyInstalled() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  HOME="$tmpdir/home"

  mkdir -p "$HOME/.homesick/repos/homeshick"

  local file_sourced_cookie="$tmpdir/homeshick-sourced"
  cat <<-EOF >"$HOME/.homesick/repos/homeshick/homeshick.sh"
        #!/usr/bin/env sh
        touch "$file_sourced_cookie"
	EOF

  # git must not be called
  # shellcheck disable=SC2329
  git() { return 1; }

  # shellcheck disable=SC2329
  _steps_extra_package_managers() {
    echo "homeshick"
  }

  run bootstrap_step_homeshick \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed (idempotent)' "$return_status"
  assertTrue 'failed to source file' "[ -f '$file_sourced_cookie' ]"
}

testHomeshickClonesRepo() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  HOME="$tmpdir/home"

  local file_sourced_cookie="$tmpdir/homeshick-sourced"

  # git must not be called
  _git_cloned=""
  # shellcheck disable=SC2329
  git() {
    case "$1" in
      clone)
        _git_cloned="yes"
        mkdir -p "$HOME/.homesick/repos/homeshick"
        cat <<-EOF >"$HOME/.homesick/repos/homeshick/homeshick.sh"
		#!/usr/bin/env sh
		touch "$file_sourced_cookie"
		EOF
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals 'git clone not called' "yes" "$_git_cloned"
  assertTrue 'failed to source file' "[ -f '$file_sourced_cookie' ]"
}

testHomeshickWritesDropinWhenBashDExists() {
  local config_file="$tmpdir/nonexistent.json"
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
        touch "$HOME/.homesick/repos/homeshick/homeshick.sh"
        ;;
    esac
  }
  # shellcheck disable=SC2329
  indent() { "$@"; }
  # shellcheck disable=SC2329
  check_cmd() { return 0; }

  run bootstrap_step_homeshick \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertTrue 'dropin file created' "[ -f '$HOME/.bash.d/homeshick.bash' ]"
  assertTrue 'dropin contains source line' \
    "grep -q 'homeshick.sh' '$HOME/.bash.d/homeshick.bash'"
}

testHomeshickAppendsToBashrcWhenNoBashD() {
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
        touch "$HOME/.homesick/repos/homeshick/homeshick.sh"
        ;;
    esac
  }
  # shellcheck disable=SC2329
  indent() { "$@"; }
  # shellcheck disable=SC2329
  check_cmd() { return 0; }

  run bootstrap_step_homeshick \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertTrue '.bashrc contains source line' \
    "grep -q 'homeshick.sh' '$HOME/.bashrc'"
}

testHomeshickDropinIsIdempotent() {
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
  touch "$HOME/.homesick/repos/homeshick/homeshick.sh"

  run bootstrap_step_homeshick \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertEquals \
    'dropin written more than once' \
    "1" \
    "$(grep -c 'homeshick.sh' "$HOME/.bash.d/homeshick.bash")"
}

testHomebrewSkipsIfAlreadyInstalled() {
  local hostname="myhost.local"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  isolatedPathFor brew
  cat <<-'EOF' >"$isolated_path/brew"
	#!/bin/sh
	exit 0
	EOF
  chmod +x "$isolated_path/brew"

  # shellcheck disable=SC2329
  _brew_installed_path() {
    echo "$isolated_path/brew"
  }
  # shellcheck disable=SC2329
  ensure_git() {
    return 0
  }

  # If download function is invoked, the test must fail
  # shellcheck disable=SC2329
  download() { return 1; }

  run bootstrap_step_homebrew \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed (idempotent)' "$return_status"
}

testHomebrewSetsNoninteractiveWhenInstalling() {
  local hostname="myhost.local"
  local os="macos"
  local version="26.2"
  local kernel="darwin"
  local arch="aarch64"

  # shellcheck disable=SC2329
  indent() { "$@"; }

  # shellcheck disable=SC2329
  _brew_installed_path() {
    return 1
  }

  # shellcheck disable=SC2329
  check_cmd() {
    case "$1" in
      brew) # brew not present
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed' "$return_status"
  assertStdoutContains 'noninteractive_set'
}

testBootstrapStepHomebrewEarlyReturnIfBrewPresent() {
  local hostname="myhost.local"
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  PATH="$isolated_path:$PATH"
  isolatedPathFor brew
  cat <<-'EOF' >"$isolated_path/brew"
	#!/bin/sh
	exit 0
	EOF
  chmod +x "$isolated_path/brew"

  # shellcheck disable=SC2329
  _brew_installed_path() {
    echo "$isolated_path/brew"
  }

  ensure_git_called=""
  # shellcheck disable=SC2329
  ensure_git() { ensure_git_called="yes"; }

  run bootstrap_step_homebrew \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed' "$return_status"
  assertEquals 'should call ensure_git' "yes" "$ensure_git_called"
}

testBootstrapStepHomebrewLinuxInstallsLinuxbrewPath() {
  local hostname="myhost.local"
  local os="cachyos"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # brew not present
  PATH="$isolated_path:$PATH"

  # shellcheck disable=SC2329
  _brew_installed_path() {
    return 1
  }

  _git_ensured=""
  # shellcheck disable=SC2329
  ensure_git() {
    _git_ensured="yes"
  }
  # shellcheck disable=SC2329
  _ensure_system_bash() { :; }
  # shellcheck disable=SC2329
  _install_linux_brew_build_deps() { :; }

  _downloaded_url=""
  # shellcheck disable=SC2329
  download() {
    _downloaded_url="$1"
    touch "$2"
  }

  _brew_env_sourced=""
  # Stub eval to capture shellenv call
  _linuxbrew_eval_called=""
  # We test the PATH update by checking that linuxbrew bin path is added

  # shellcheck disable=SC2329
  mktemp_file() { mktemp; }
  # shellcheck disable=SC2329
  cleanup_file() { :; }
  # shellcheck disable=SC2329
  indent() { "$@" 2>/dev/null || true; }

  run bootstrap_step_homebrew \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  # The function should attempt download of the install script
  assertTrue 'should attempt download' \
    "echo '$_downloaded_url' | grep -q 'Homebrew/install'"
}

testAurSkipsIfParuAlreadyInstalled() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'should succeed (idempotent)' "$return_status"
}

testAurOnArchInstallsGitIfMissing() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'pacman git install was called' \
    "echo '$_pacman_args' | grep -q 'git'"
}

testAurOnArchClonesParu() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'paru URL used' \
    "echo '$_git_url' | grep -q 'paru'"
}

testAurOnCachyOsInstallsParuBin() {
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
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'pacman paru-bin install was called' \
    "echo '$_pacman_args' | grep -q 'paru-bin'"
}

testBootstrapStepBashrcInstallsFramework() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  # Pre-condition: bashrc not yet installed
  rm -rf "$HOME/.bash"

  local _downloaded_url=""
  local _downloaded_script=""
  # shellcheck disable=SC2329
  download() {
    _downloaded_url="$1"
    touch "$2"
    _downloaded_script="$2"
  }

  # shellcheck disable=SC2329
  _ensure_bash() { :; }
  # shellcheck disable=SC2329
  ensure_git() { :; }
  # shellcheck disable=SC2329
  mktemp_file() { mktemp; }
  # shellcheck disable=SC2329
  cleanup_file() { :; }
  # shellcheck disable=SC2329
  indent() { :; }

  run bootstrap_step_bashrc \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function succeeded' "$return_status"
  assertTrue 'downloaded install script' \
    "echo '$_downloaded_url' | grep -q 'fnichol/bashrc'"
}

testBootstrapStepBashrcSkipsIfAlreadyInstalled() {
  local hostname="myhost.local"
  local os="arch"
  local version=""
  local kernel="linux"
  local arch="x86_64"

  mkdir -p "$HOME/.bash"
  touch "$HOME/.bash/bashrc"

  _ensure_bash_called=""
  # shellcheck disable=SC2329
  _ensure_bash() { _ensure_bash_called="yes"; }
  # shellcheck disable=SC2329
  ensure_git() { :; }

  _install_called=""
  # shellcheck disable=SC2329
  download() { _install_called="yes"; }

  run bootstrap_step_bashrc \
    "$config_file" "$data_home" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function succeeded' "$return_status"
  assertEquals 'should not re-download' "" "$_install_called"
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
