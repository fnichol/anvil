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

# Ensures that a version of Git is present on the system
ensure_git() {
  local os="${1:-$(facts_os)}"

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

git_current_sha() {
  local path="$1"

  ensure_git

  git -C "$path" rev-parse HEAD
}
