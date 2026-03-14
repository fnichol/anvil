#!/usr/bin/env sh
# shellcheck disable=SC3043

# Extra package managers that aren't built-in/system managers
__ANVIL_EXTRA_PACKAGE_MANAGERS__="aur bashrc homebrew homeshick"

# Calculates packages to install (desired - installed)
convergence_delta() {
  local desired="$1"
  local installed="$2"

  # Find all all packages in desired but not in installed
  echo "$desired" | while read -r pkg; do
    if [ -n "$pkg" ] && ! echo "$installed" | grep -q "^${pkg}$"; then
      echo "$pkg"
    fi
  done
}

# Builds complete desired package list from tags
desired_packages() {
  local root="$1"
  local os="$2"
  local arch="$3"
  local package_type="$4"
  shift 4
  local tags="$*"

  # shellcheck source=lib/anvil/jq.sh
  . "$root/lib/anvil/jq.sh"
  # shellcheck source=lib/anvil/tags.sh
  . "$root/lib/anvil/tags.sh"

  local all_pkgs=""

  for tag in $tags; do
    local tag_pkgs
    tag_pkgs="$(
      tags_packages_for "$root" "$tag" "$os" "$arch" "$package_type"
    )"

    if [ -n "$tag_pkgs" ]; then
      all_pkgs="${all_pkgs}${all_pkgs:+
}${tag_pkgs}"
    fi
  done

  # Remove duplicates and sort
  echo "$all_pkgs" | sort -u
}

# Returns the set of extra package managers required by the given active tags.
#
# The extra package managers are in addition to the native system package
# managers such as Homebrew, AUR, etc. that require installation and setup
# before they can be used.
#
# * `@param [String]` root directory of the codebase
# * `@param [String]` path to config file
# * `@param [String]` operating system (e.g. "cachyos", "macos")
# * `@param [String]` architecture (e.g. "x86_64", "aarch64")
# * `@stdout` newline-delimited list of unique/sorted extra package manager
#             names
# * `@return 0` if successful
#
# # Global Variables
#
# * `__ANVIL_EXTRA_PACKAGE_MANAGERS__`: all non-system package managers
_steps_extra_package_managers() {
  local root="$1"
  local config_path="$2"
  local os="$3"
  local arch="$4"

  ensure_jq

  local tags
  tags="$(config_read_tags "$config_path")"

  # No tags are configured, early return
  if [ -z "$tags" ]; then
    return 0
  fi

  local resolved_tags
  resolved_tags="$(tags_resolve "$root" "$tags")"

  local all_package_types=""
  for tag in $resolved_tags; do
    local tag_file
    tag_file="$(tags_path_for "$root" "$tag")"

    if [ ! -f "$tag_file" ]; then
      continue
    fi

    local package_types
    package_types="$(
      jq -r \
        --arg os "$os" \
        --arg arch "$arch" \
        '[
          (.packages.all.all // {} | keys[]),
          (.packages.all[$arch] // {} | keys[]),
          (.packages[$os].all // {} | keys[]),
          (.packages[$os][$arch] // {} | keys[])
        ][]' \
        "$tag_file"
    )"

    all_package_types="$(printf '%s\n%s' "$all_package_types" "$package_types")"
  done

  local extras
  extras="$(echo "$__ANVIL_EXTRA_PACKAGE_MANAGERS__" | tr ' ' '|')"

  printf '%s\n' "$all_package_types" \
    | sort -u \
    | grep -E "^($extras)$" \
    || true
}
