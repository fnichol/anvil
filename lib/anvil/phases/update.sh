#!/usr/bin/env sh
# shellcheck disable=SC3043

# Returns platform-specific update steps, one per package manager.
#
# Emits a sync step before each upgrade step so indices are fresh.
#
# **NOTE**: OpenBSD uses `pkg_add -u` which folds sync and upgrade, so no
# separate sync step is needed there.
update_steps() {
  local _root="$1"
  shift
  local _config_path="$1"
  shift
  local os="$1"
  shift
  local _version="$1"
  shift
  local _kernel="$1"
  shift
  local _arch="$1"
  shift

  case "$os" in
    alpine)
      echo "apk_sync"
      echo "apk"
      ;;
    arch | cachyos)
      echo "pacman_sync"
      echo "pacman"
      echo "aur"
      ;;
    debian | ubuntu)
      echo "apt_sync"
      echo "apt"
      ;;
    freebsd)
      echo "freebsd_pkg_sync"
      echo "freebsd_pkg"
      ;;
    macos)
      echo "homebrew_sync"
      echo "homebrew"
      echo "homebrew_cask"
      ;;
    openbsd)
      echo "openbsd_pkg"
      ;;
  esac

  echo "homeshick"
}

update_step_homebrew_sync() {
  need_cmd brew

  info "[update:homebrew_sync] Updating Homebrew"
  indent brew update
}

update_step_homebrew() {
  need_cmd brew

  info "[update:homebrew] Upgrading Homebrew formulae"
  indent env HOMEBREW_NO_AUTO_UPDATE=true brew upgrade
}

update_step_homebrew_cask() {
  need_cmd brew

  info "[update:homebrew_cask] Upgrading Homebrew casks"
  indent env HOMEBREW_NO_AUTO_UPDATE=true brew upgrade --cask
}

update_step_pacman_sync() {
  need_cmd pacman

  info "[update:pacman_sync] Syncing Pacman package index"
  indent as_root pacman -Sy --noconfirm
}

update_step_pacman() {
  need_cmd pacman

  info "[update:pacman] Upgrading Pacman packages"
  indent as_root pacman -Su --noconfirm
}

update_step_aur() {
  need_cmd paru

  info "[update:aur] Upgrading AUR packages"
  indent paru -Su --noconfirm
}

update_step_apt_sync() {
  need_cmd apt-get

  info "[update:apt_sync] Syncing Apt package index"
  indent as_root apt-get update
}

update_step_apt() {
  need_cmd apt-get

  info "[update:apt] Upgrading Apt packages"
  indent as_root apt-get -y dist-upgrade
}

update_step_apk_sync() {
  need_cmd apk

  info "[update:apk_sync] Syncing Apk package index"
  indent as_root apk update
}

update_step_apk() {
  need_cmd apk

  info "[update:apk] Upgrading apk packages"
  indent as_root apk upgrade
}

update_step_freebsd_pkg_sync() {
  need_cmd pkg

  info "[update:pkg_sync] Syncing Pkg package index"
  indent as_root pkg update
}

update_step_freebsd_pkg() {
  need_cmd pkg

  info "[update:pkg] Upgrading Pkg packages"
  indent as_root pkg upgrade --yes --no-repo-update
}

update_step_openbsd_pkg() {
  need_cmd pkg_add

  info "[update:pkg_add] Upgrading Pkg packages"
  indent as_root pkg_add -u
}

# Pulls the latest commits for all installed Homeshick castles.
#
# Guards against homeshick not being installed — returns 0 with a warning
# rather than failing, so a fresh machine can run the update phase without
# having completed the bootstrap phase first.
update_step_homeshick() {
  local homeshick_path="$HOME/.homesick/repos/homeshick"

  if [ ! -d "$homeshick_path" ]; then
    warn "[update:homeshick] Homeshick not installed, skipping"
    return 0
  fi

  # shellcheck source=/dev/null
  . "$homeshick_path/homeshick.sh"

  info "[update:homeshick] Pulling castle updates"
  indent homeshick pull --batch
}
