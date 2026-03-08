#!/usr/bin/env sh
# shellcheck disable=SC3043

# Returns platform-specific install steps, one package manager per step.
install_steps() {
  local os="$1"
  shift
  local _version="$1"
  shift
  local _kernel="$1"
  shift
  local _arch="$1"
  shift

  case "$os" in
    macos)
      echo "homebrew"
      echo "homebrew_cask"
      ;;
    arch | cachyos)
      echo "pacman"
      echo "aur"
      ;;
    ubuntu)
      echo "apt"
      ;;
    alpine)
      echo "apk"
      ;;
    openbsd)
      echo "pkg_add"
      ;;
    freebsd)
      echo "pkg"
      ;;
    *)
      warn "install: no steps defined for OS: $os"
      ;;
  esac
}

install_step_homebrew() {
  local root="$1"
  shift
  local _hostname="$1"
  shift
  local os="$1"
  shift
  local _version="$1"
  shift
  local _kernel="$1"
  shift
  local arch="$1"
  shift

  local package_type="homebrew"

  need_cmd tr
  need_cmd wc

  # shellcheck source=lib/anvil/jq.sh
  . "$root/lib/anvil/jq.sh"
  # shellcheck source=lib/anvil/config.sh
  . "$root/lib/anvil/config.sh"
  # shellcheck source=lib/anvil/tags.sh
  . "$root/lib/anvil/tags.sh"
  # shellcheck source=lib/anvil/discovery.sh
  . "$root/lib/anvil/discovery.sh"
  # shellcheck source=lib/anvil/convergence.sh
  . "$root/lib/anvil/convergence.sh"

  local tags
  tags="$(config_read_tags)"

  # No tags are configured, early return
  if [ -z "$tags" ]; then
    return 0
  fi

  local resolved_tags
  resolved_tags="$(tags_resolve "$root" "$tags")"

  local desired_packages
  desired_packages="$(
    desired_packages "$root" "$os" "$arch" "$package_type" "$resolved_tags"
  )"

  local installed_packages
  installed_packages="$(discover_installed_packages "$os" "$package_type")"

  local packages_to_install
  packages_to_install="$(
    convergence_delta "$desired_packages" "$installed_packages"
  )"

  local pending_count=0
  if [ -n "$packages_to_install" ]; then
    pending_count="$(echo "$packages_to_install" | wc -l | tr -d ' ')"
  fi

  if [ "$pending_count" -eq 0 ]; then
    info "  [install:$package_type] System is already in desired state"
    return 0
  fi

  info "  [install:$package_type] Packages to install: $pending_count"

  # Load platform libraries and install
  . "$root/lib/common.sh"
  . "$root/lib/unix.sh"
  . "$root/lib/darwin.sh"

  local _arch
  case "$arch" in
    aarch64) _arch="arm64" ;;
    *)       _arch="$arch" ;;
  esac
  darwin_setup_package_system
  unset _arch

  install_packages "$root" "$os" "$packages_to_install"
}

install_step_homebrew_cask() {
  # TODO: implement

  info "install:homebrew_cask - stub"
}

install_step_pacman() {
  # TODO: implement

  info "install:pacman - stub"
}

install_step_aur() {
  # TODO: implement

  info "install:aur - stub"
}

install_step_apt() {
  # TODO: implement

  info "install:apt - stub"
}

install_step_apk() {
  # TODO: implement

  info "install:apk - stub"
}

install_step_pkg_add() {
  # TODO: implement

  info "install:pkg_add - stub"
}

install_step_pkg() {
  # TODO: implement

  info "install:pkg - stub"
}
