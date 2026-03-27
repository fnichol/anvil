#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/convergence.sh
. "$SRC_ROOT/lib/anvil/convergence.sh"
# shellcheck source=lib/anvil/sudo.sh
. "$SRC_ROOT/lib/anvil/sudo.sh"

# Returns platform-specific update steps, one per package manager.
#
# Emits a sync step before each upgrade step so indices are fresh.
#
# **NOTE**: OpenBSD uses `pkg_add -u` which folds sync and upgrade, so no
# separate sync step is needed there.
update_steps() {
  local root="$1"
  shift
  local config_path="$1"
  shift
  local os="$1"
  shift
  local _version="$1"
  shift
  local _kernel="$1"
  shift
  local arch="$1"
  shift

  local extra_managers
  extra_managers="$(
    _steps_extra_package_managers "$root" "$config_path" "$os" "$arch"
  )"

  # Native system package managers sync + upgrade are first and unconditional
  case "$os" in
    alpine)
      echo "apk_sync"
      echo "apk"
      ;;
    arch | cachyos)
      echo "pacman_sync"
      echo "pacman"
      ;;
    debian | ubuntu)
      echo "apt_sync"
      echo "apt"
      ;;
    freebsd)
      echo "freebsd_pkg_sync"
      echo "freebsd_pkg"
      ;;
    openbsd)
      echo "openbsd_pkg"
      ;;
  esac

  # Extra package managers sync + upgrade only when tags declare them
  if echo "$extra_managers" | grep -q "^homebrew$"; then
    echo "homebrew_sync"
    echo "homebrew"
    if [ "$os" = "macos" ]; then
      echo "homebrew_cask"
    fi
  fi

  if echo "$extra_managers" | grep -q "^aur$"; then
    echo "aur"
  fi

  for extra_manager in bashrc homeshick; do
    if echo "$extra_managers" | grep -q "^${extra_manager}$"; then
      echo "$extra_manager"
    fi
  done

  # Mise is only installed on Linux and macOS systems (not on BSD systems)
  case "$os" in
    freebsd | openbsd) ;;
    *)
      if echo "$extra_managers" | grep -q "^mise$"; then
        echo "mise_sync"
        echo "mise"
      fi
      ;;
  esac
}

update_step_homebrew_sync() {
  need_cmd brew

  info "Updating Homebrew"
  indent brew update
}

update_step_homebrew() {
  need_cmd brew

  info "Upgrading Homebrew formulae"
  indent env HOMEBREW_NO_AUTO_UPDATE=true brew upgrade
}

update_step_homebrew_cask() {
  need_cmd brew

  info "Upgrading Homebrew casks"
  indent env HOMEBREW_NO_AUTO_UPDATE=true brew upgrade --cask
}

update_step_pacman_sync() {
  need_cmd pacman

  info "Syncing Pacman package index"
  indent as_root pacman -Sy --noconfirm
}

update_step_pacman() {
  need_cmd pacman

  info "Upgrading Pacman packages"
  indent as_root pacman -Su --noconfirm
}

update_step_aur() {
  need_cmd paru

  info "Upgrading AUR packages"
  indent paru -Su --noconfirm
}

update_step_apt_sync() {
  need_cmd apt-get

  info "Syncing Apt package index"
  indent as_root apt-get update
}

update_step_apt() {
  need_cmd apt-get

  info "Upgrading Apt packages"
  indent as_root apt-get -y dist-upgrade
}

update_step_apk_sync() {
  need_cmd apk

  info "Syncing Apk package index"
  indent as_root apk update
}

update_step_apk() {
  need_cmd apk

  info "Upgrading apk packages"
  indent as_root apk upgrade
}

update_step_freebsd_pkg_sync() {
  need_cmd pkg

  info "Syncing Pkg package index"
  indent as_root pkg update
}

update_step_freebsd_pkg() {
  need_cmd pkg

  info "Upgrading Pkg packages"
  indent as_root pkg upgrade --yes --no-repo-update
}

update_step_openbsd_pkg() {
  need_cmd pkg_add

  info "Upgrading Pkg packages"
  indent as_root pkg_add -u
}

# Pulls the latest commits for all installed Homeshick castles.
#
# Guards against homeshick not being installed — returns 0 with a warning
# rather than failing, so a fresh machine can run the update phase without
# having completed the bootstrap phase first.
update_step_homeshick() {
  local homeshick_path="$HOME/.homesick/repos/homeshick"

  if [ ! -f "$homeshick_path/homeshick.sh" ]; then
    warn "Homeshick not installed, skipping"
    return 0
  fi

  if ! indent homeshick --batch check >/dev/null; then
    info "Pulling castle updates"
    indent homeshick --batch pull
    indent homeshick --batch link
  fi
}

update_step_bashrc() {
  local bashrc="$HOME/.bash/bashrc"

  if [ ! -f "$bashrc" ]; then
    warn "Bashrc not installed, skipping"
    return 0
  fi

  if ! indent _run_bashrc check >/dev/null; then
    info "Pulling updates"
    indent _run_bashrc update
  fi
}

update_step_mise_sync() {
  need_cmd mise

  info "Updating Mise"
  indent mise self-update --yes
}

update_step_mise() {
  need_cmd mise

  info "Upgrading Mise global tools"

  # **NOTE**: Ensure that current directory isn't a project with its own local
  # Mise configuration. We want to upgrade the *global* tools, not any local
  # tool that might be activated. Unfortunetly, there doesn't appear to be an
  # option to only select global tools for upgrade.
  (cd "/" && indent mise upgrade)
}

_run_bashrc() {
  bash <<-EOF
	# shellcheck source=/dev/null
	. "$bashrc"
        bashrc $*
	EOF
}
