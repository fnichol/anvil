#!/usr/bin/env sh
# shellcheck disable=SC3043

# Returns platform-specific bootstrap steps.
#
# **Note**: Only steps for package managers that require installation are
# emitted. Pre-installed system package managers such as apt, apk, pacman,
# pkg_add, pkg are omitted as no installation is required.
bootstrap_steps() {
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
      echo "homeshick"
      echo "bashrc"
      ;;
    arch | cachyos)
      echo "aur"
      echo "homeshick"
      echo "bashrc"
      ;;
    *)
      # No bootstrap needed: system package manager already present
      ;;
  esac
}

bootstrap_step_homebrew() {
  # TODO: install Homebrew if not present

  info "bootstrap:homebrew - stub"
}

bootstrap_step_aur() {
  # TODO: install paru AUR helper if not present

  info "bootstrap:aur_helper - stub"
}

bootstrap_step_homeshick() {
  # TODO: install homeshick if not present

  info "bootstrap:homeshick - stub"
}

bootstrap_step_bashrc() {
  # TODO: install bashrc if not present

  info "bootstrap:bashrc - stub"
}
