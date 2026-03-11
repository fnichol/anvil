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
