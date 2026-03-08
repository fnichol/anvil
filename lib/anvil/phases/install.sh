#!/usr/bin/env sh
# shellcheck disable=SC3043

# Returns platform-specific install steps, one package manager per step.
#
# **Note**: Branches on `$__ANVIL_OS` set by facts:gather.
install_steps() {
  case "$__ANVIL_OS" in
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
      warn "install: no steps defined for OS: $__ANVIL_OS"
      ;;
  esac
}

install_step_homebrew() {
  # TODO: implement

  info "install:homebrew - stub"
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
