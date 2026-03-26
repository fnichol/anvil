#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/convergence.sh}"
}

testCalculatePackagesToInstall() {
  # Desired: git, vim, curl
  # Installed: git, curl,
  # Expected: vim

  local desired="git
vim
curl"

  local installed="git
curl"

  run convergence_delta "$desired" "$installed"

  assertTrue "convergence_delta failed" "$return_status"
  assertStdoutContains "vim"

  # Should not include git or curl
  assertFalse 'Should not include already installed packages' \
    "cat '$stdout' | grep -q '^git$'"
  assertFalse 'Should not include already installed packages' \
    "cat '$stdout' | grep -q '^curl$'"
}

testStepsExtraPackageManagersReturnsEmptyWhenNoTags() {
  run _steps_extra_package_managers "$root" "" "cachyos" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
}

testStepsExtraPackageManagersDetectsHomebrewOnLinux() {
  writeConfigFile

  # shellcheck disable=SC2329
  config_resolve_tags() { echo "brew-test"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "brew-test"; }

  local tag_file="$tmpdir/data/tags/brew-test.json"
  mkdir -p "$(dirname "$tag_file")"
  jq -n '
    {
      name: "brew-test",
      depends_on: [],
      packages: {
        cachyos: {
          all: {
            homebrew: ["some-tool"]
          }
        }
      }
    }
  ' >"$tag_file"

  run _steps_extra_package_managers "$tmpdir" "" "cachyos" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "homebrew"
  assertFalse 'should not include aur' "grep -q '^aur$' '$stdout'"
}

testStepsExtraPackageManagersDetectsAurWhenDeclared() {
  writeConfigFile

  # shellcheck disable=SC2329
  config_resolve_tags() { echo "aur-test"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "aur-test"; }

  local tag_file="$tmpdir/data/tags/aur-test.json"
  mkdir -p "$tmpdir/data/tags"
  jq -n '
    {
      name: "aur-test",
      depends_on: [],
      packages: {
        cachyos: {
          all: {
            aur: ["some-aur-pkg"]
          }
        }
      }
    }
  ' >"$tag_file"

  run _steps_extra_package_managers "$tmpdir" "" "cachyos" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "aur"
}

testStepsExtraPackageManagersDetectsHomeshickFromAllOs() {
  writeConfigFile

  # shellcheck disable=SC2329
  config_resolve_tags() { echo "dotfiles"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "dotfiles"; }

  local tag_file="$tmpdir/data/tags/dotfiles.json"
  mkdir -p "$tmpdir/data/tags"
  jq -n '
    {
      name: "dotfiles",
      depends_on: [],
      packages: {
        all: {
          all: {
            homeshick: ["fnichol/dotfiles"]
          }
        }
      }
    }
  ' >"$tag_file"

  run _steps_extra_package_managers "$tmpdir" "" "ubuntu" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "homeshick"
}

testStepsExtraPackageManagersIgnoresNativePackageManagers() {
  writeConfigFile

  # shellcheck disable=SC2329
  config_resolve_tags() { echo "base"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "base"; }

  local tag_file="$tmpdir/data/tags/base.json"
  mkdir -p "$tmpdir/data/tags"
  jq -n '
    {
      name: "base",
      depends_on: [],
      packages: {
        cachyos: {
          all: {
            pacman: ["git"]
          }
        }
      }
    }
  ' >"$tag_file"

  run _steps_extra_package_managers "$tmpdir" "" "cachyos" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
}

testStepsExtraPackageManagersDeduplicatesAcrossTags() {
  writeConfigFile

  # shellcheck disable=SC2329
  config_resolve_tags() { echo "tag-a tag-b"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "tag-a tag-b"; }

  local tag_a_file="$tmpdir/data/tags/tag-a.json"
  local tag_b_file="$tmpdir/data/tags/tag-b.json"

  mkdir -p "$tmpdir/data/tags"
  jq -n '
    {
      name: "tag-a",
      depends_on: [],
      packages: {
        cachyos: {
          all: {
            homebrew: ["a"]
          }
        }
      }
    }
  ' >"$tag_a_file"
  jq -n '
    {
      name: "tag-b",
      depends_on: [],
      packages: {
        cachyos: {
          all: {
            homebrew: ["b"]
          }
        }
      }
    }
  ' >"$tag_b_file"

  run _steps_extra_package_managers "$tmpdir" "" "cachyos" "x86_64"

  assertTrue 'function failed' "$return_status"
  # homebrew should appear exactly once
  assertEquals 'homebrew appears once' "1" \
    "$(grep -c '^homebrew$' "$stdout" || echo 0)"
}

testStepsExtraPackageManagersDetectsMise() {
  writeConfigFile

  # shellcheck disable=SC2329
  config_resolve_tags() { echo "mise-test"; }
  # shellcheck disable=SC2329
  tags_resolve() { echo "$2"; }
  # shellcheck disable=SC2329
  tags_path_for() { echo "$tmpdir/mise-test.json"; }

  cat <<-'EOF' >"$tmpdir/mise-test.json"
	{
	  "name": "mise-test",
	  "packages": {
	    "arch": {
	      "all": {"mise": ["node@lts"]}
	    }
	  }
	}
	EOF

  run _steps_extra_package_managers "$root" "" "arch" "x86_64"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "mise"
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "$shunit2"
