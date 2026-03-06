#!/usr/bin/env sh
# shellcheck disable=SC3043

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

# Installs packages using platform-specific installer.
#
# * `@param [String]` root directory path
# * `@param [String]` operating system (e.g., "macos")
# * `@param [String]` package list (newline-separated)
# * `@return 0` if successful
#
# # Examples
#
# Basic usage:
#
# ```sh
# packages="git
# curl
# vim"
# install_packages "/path/to/anvil" "macos" "$packages"
# ```
install_packages() {
  local root="$1"
  local os="$2"
  local packages="$3"

  need_cmd wc

  local total
  total="$(echo "$packages" | grep -c . || echo 0)"
  local current=0

  case "$os" in
    macos)
      # Load platform libraries
      . "$root/lib/common.sh"
      . "$root/lib/unix.sh"
      . "$root/lib/darwin.sh"

      # Create cache file for performance
      local cache
      cache="$(mktemp_file)"
      cleanup_file "$cache"
      rm -f "$cache"

      echo "$packages" | while IFS= read -r pkg; do
        if [ -n "$pkg" ]; then
          current=$((current + 1))
          info "[$current/$total] Installing: $pkg"
          darwin_install_pkg "$pkg" "$cache"
        fi
      done
      ;;
    *)
      die "Platform not yet supported: $os"
      ;;
  esac
}
