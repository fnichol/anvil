#!/usr/bin/env sh
# shellcheck disable=SC3043

# Returns platform-specific bootstrap steps.
#
# **Note**: Only steps for package managers that require installation are
# emitted. Pre-installed system package managers such as apt, apk, pacman,
# pkg_add, pkg are omitted as no installation is required.
bootstrap_steps() {
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

  # Package manager bootstrap (only where installation is required)
  case "$os" in
    macos)
      echo "homebrew"
      ;;
    arch | cachyos)
      echo "aur"
      ;;
  esac

  # User environment bootstrap (every platform)
  echo "bashrc"
  echo "homeshick"
}

bootstrap_step_aur() {
  local _root="$1"
  shift
  local _config_file="$1"
  shift
  local _hostname="$1"
  shift
  local os="$1"
  shift
  local _version="$1"
  shift
  local _kernel="$1"
  shift
  local _arch="$1"
  shift

  # Early return if already installed
  if check_cmd paru; then
    return 0
  fi

  _ensure_git "$os"

  case "$os" in
    cachyos)
      info "Installing paru-bin package"
      indent as_root pacman -Sy --noconfirm
      indent as_root pacman -S --needed --noconfirm paru-bin
      ;;
    *)
      # **NOTE**: As of 2026-03 building Paru yields the best results due to
      # libalpm support issues.
      #
      # See: https://github.com/Morganamilo/paru/issues/1454

      # Ensure build dependencies and toolchain are present
      indent as_root pacman -Sy --noconfirm
      indent as_root pacman -S --needed --noconfirm base-devel cargo

      local build_user=nobody
      local build_group=nobody

      local build_dir
      build_dir="$(mktemp_directory)"
      cleanup_directory "$build_dir"
      mkdir -p "$build_dir/git"
      mkdir -p "$build_dir/home"

      info "Cloning AUR paru"
      indent git clone https://aur.archlinux.org/paru.git "$build_dir/git"
      chown -R "$build_user:$build_group" "$build_dir"
      info "Building paru package"
      (
        cd "$build_dir/git" \
          && indent sudo -u "$build_user" \
            env HOME="$build_dir/home" \
            makepkg --syncdeps --noconfirm --clean
      )
      info "Installing paru package"
      indent as_root pacman \
        -U \
        --needed \
        --noconfirm \
        "$build_dir"/git/paru-[0-9]*.pkg.tar.zst
      ;;
  esac
}

bootstrap_step_homebrew() {
  local _root="$1"
  shift
  local _config_file="$1"
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

  # Early return if already installed
  if check_cmd brew; then
    # Ensure Git is installed for updating later
    _ensure_git "$os"

    return 0
  fi

  _ensure_git "$os"
  _ensure_system_bash "$os"

  local install_sh
  install_sh="$(mktemp_file)"
  cleanup_file "$install_sh"

  download \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
    "$install_sh"

  info "Installing Homebrew"
  indent env NONINTERACTIVE=1 bash "$install_sh" </dev/null

  # Update PATH for the current process so subsequent steps can find `brew`.
  #
  # - Apple Silicon installs to `/opt/homebrew`
  # - Intel to `/usr/local` (already in PATH)
  case "$arch" in
    aarch64)
      if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
      ;;
  esac
}

bootstrap_step_homeshick() {
  local _root="$1"
  shift
  local _config_file="$1"
  shift
  local _hostname="$1"
  shift
  local os="$1"
  shift

  local homeshick_path="$HOME/.homesick/repos/homeshick"

  # Early return if already installed
  if [ -d "$homeshick_path" ]; then
    # Ensure Git is installed for updating later
    _ensure_git "$os"

    return 0
  fi

  _ensure_git "$os"

  info "Installing homeshick"
  indent git clone https://github.com/andsens/homeshick.git "$homeshick_path"

  # Shell integration: write source line to drop-in or ~/.bashrc
  local source_line
  # shellcheck disable=SC2016
  source_line='source "$HOME/.homesick/repos/homeshick/homeshick.sh"'

  if [ -d "$HOME/.bash.d" ]; then
    local dropin="$HOME/.bash.d/homeshick.bash"
    if [ ! -f "$dropin" ]; then
      printf '%s\n' "$source_line" >"$dropin"
    fi
  else
    if ! grep -q -F 'homeshick.sh' "$HOME/.bashrc" 2>/dev/null; then
      printf '\n%s\n' "$source_line" >>"$HOME/.bashrc"
    fi
  fi
}

bootstrap_step_bashrc() {
  local _root="$1"
  shift
  local _config_file="$1"
  shift
  local _hostname="$1"
  shift
  local os="$1"
  shift

  # Early return if already installed
  if [ -f "${HOME}/.bash/bashrc" ]; then
    # Ensure Bash is installed for updating later
    _ensure_bash "$os"
    # Ensure Git is installed for updating later
    _ensure_git "$os"

    return 0
  fi

  _ensure_bash "$os"
  _ensure_git "$os"

  local install_local_sh
  install_local_sh="$(mktemp_file)"
  cleanup_file "$install_local_sh"

  download \
    https://raw.githubusercontent.com/fnichol/bashrc/master/contrib/install-local \
    "$install_local_sh"

  info "Installing fnichol/bashrc shell framework"
  indent bash "$install_local_sh"
}

_ensure_bash() {
  local os="$1"

  # Ensure Bash is available and install via system package manager if not
  if ! check_cmd bash; then
    case "$os" in
      alpine)
        info "Installing bash"
        indent as_root apk add --no-cache bash
        ;;
      arch)
        info "Installing bash"
        indent as_root pacman -Sy --noconfirm
        indent as_root pacman -S --noconfirm bash
        ;;
      bazzite | cachyos | truenas)
        need_cmd bash
        ;;
      debian | ubuntu)
        info "Installing bash"
        indent as_root apt-get install --no-install-recommends -y bash
        ;;
      freebsd)
        info "Installing bash"
        indent as_root pkg install -y bash
        ;;
      macos)
        info "Installing bash"
        indent env HOMEBREW_NO_AUTO_UPDATE=true brew install bash </dev/null
        ;;
      openbsd)
        info "Installing bash"
        indent as_root pkg_add bash
        ;;
    esac
  fi
}

_ensure_git() {
  local os="$1"

  # Ensure Git is available and install via system package manager if not
  if ! check_cmd git; then
    case "$os" in
      alpine)
        info "Installing git"
        indent as_root apk add --no-cache git
        ;;
      arch)
        info "Installing git"
        indent as_root pacman -Sy --noconfirm
        indent as_root pacman -S --noconfirm git
        ;;
      bazzite | cachyos | macos | truenas)
        # Note: on macOS, Homebrew step ensures Xcode CLT
        need_cmd git
        ;;
      debian | ubuntu)
        info "Installing git"
        indent as_root apt-get install --no-install-recommends -y git
        ;;
      freebsd)
        info "Installing git"
        indent as_root pkg install -y git
        ;;
      openbsd)
        info "Installing git"
        indent as_root pkg_add git
        ;;
    esac
  fi
}

# Ensures Bash is available on system and selectively installs via a core
# system package manager if not.
#
# **Note**: The implementation cannot rely on non-system package managers such
# as Homebrew, AUR, etc.
_ensure_system_bash() {
  local os="$1"

  if ! check_cmd bash; then
    case "$os" in
      alpine)
        info "Installing bash"
        indent as_root apk add --no-cache bash
        ;;
      arch)
        info "Installing bash"
        indent as_root pacman -Sy --noconfirm
        indent as_root pacman -S --noconfirm bash
        ;;
      bazzite | cachyos | macos | truenas)
        # NOTE: macOS should have `/bin/bash` installed and on PATH
        need_cmd bash
        ;;
      debian | ubuntu)
        info "Installing bash"
        indent as_root apt-get install --no-install-recommends -y bash
        ;;
      freebsd)
        info "Installing bash"
        indent as_root pkg install -y bash
        ;;
      openbsd)
        info "Installing bash"
        indent as_root pkg_add bash
        ;;
    esac
  fi
}
