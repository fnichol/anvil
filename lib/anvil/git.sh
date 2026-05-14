#!/usr/bin/env sh
# shellcheck disable=SC3043

# Import cookie to prevent circular loading
if [ -n "${__ANVIL_SOURCED_GIT__:-}" ]; then
  return 0
else
  __ANVIL_SOURCED_GIT__=true
fi

# shellcheck source=lib/anvil/facts.sh
. "$SRC_ROOT/lib/anvil/facts.sh"
# shellcheck source=lib/anvil/sudo.sh
. "$SRC_ROOT/lib/anvil/sudo.sh"

# Ensures that a version of Git is present on the system
ensure_git() {
  local os="${1:-$(facts_os)}"

  if [ "$os" = "macos" ]; then
    if [ ! -e "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
      detect_sudo
      get_sudo "$(facts_hostname)"
      _install_macos_clt
    fi
  fi

  # Ensure Git is available and install via system package manager if not
  if ! check_cmd git; then
    case "$os" in
      alpine)
        detect_sudo
        get_sudo "$(facts_hostname)"

        info "Installing git"
        indent as_root apk add --no-cache git
        ;;
      arch)
        detect_sudo
        get_sudo "$(facts_hostname)"

        info "Installing git"
        indent as_root pacman -Sy --noconfirm
        indent as_root pacman -S --noconfirm git
        ;;
      bazzite | cachyos | macos | truenas)
        # Note: on macOS, Homebrew step ensures Xcode CLT
        need_cmd git
        ;;
      debian | ubuntu)
        detect_sudo
        get_sudo "$(facts_hostname)"

        info "Installing git"
        indent as_root apt-get install --no-install-recommends -y git
        ;;
      fedora)
        detect_sudo
        get_sudo "$(facts_hostname)"

        info "Installing git"
        indent as_root dnf install --assumeyes git
        ;;
      freebsd)
        detect_sudo
        get_sudo "$(facts_hostname)"

        info "Installing git"
        indent as_root pkg install -y git
        ;;
      openbsd)
        detect_sudo
        get_sudo "$(facts_hostname)"

        info "Installing git"
        indent as_root pkg_add git
        ;;
    esac
  fi
}

git_current_sha() {
  local path="$1"

  ensure_git

  git -C "$path" rev-parse HEAD
}

git_remote_current_sha() {
  local url="$1"
  local pattern="${2:-HEAD}"

  ensure_git

  git ls-remote "$url" "$pattern" | awk '{print $1}'
}

git_update_checkout() {
  local path="$1"
  local ref="$2"

  ensure_git

  git -C "$path" fetch origin || return 1
  git -C "$path" reset --hard "origin/$ref"
}

# Installs Command Line Tools on macOS systems.
#
# # Implementation Notes
#
# This implementation is graciously borrowed and modified from Homebrew's
# `install.sh` script.
#
# Source: https://github.com/Homebrew/install/blob/61f57debbf8b06e07daf60e514bed21f81df493e/install.sh#L852-L871
_install_macos_clt() {
  # This temporary file prompts the 'softwareupdate' utility to list the
  # Command Line Tools
  local clt_placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  as_root touch "$clt_placeholder"

  info_start "Determining version of Command Line Tools with softwareupdate"
  local clt_label
  clt_label="$(
    /usr/sbin/softwareupdate --list \
      | sed -n 's/.*Label: \(Command Line Tools.*\)/\1/p' \
      | sort -V \
      | tail -n 1
  )"
  if [ -z "$clt_label" ]; then
    echo ""
    warn "Failed to determine macOS Command Line Tools version to install."
    warn "Please ensure Command Line Tools are properly installed and try again"
    die "Command Line Tools could not be installed"
  fi
  info_end

  info "Installing $clt_label"
  indent as_root /usr/sbin/softwareupdate \
    -i "$clt_label" \
    --verbose
  indent as_root /usr/bin/xcode-select \
    --switch /Library/Developer/CommandLineTools

  # Clean up temporary file
  as_root rm -f "$clt_placeholder"
}
