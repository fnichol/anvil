#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"

discover_installed_packages() {
  local os="$1"
  local package_type="$2"

  case "$os" in
    alpine)
      case "$package_type" in
        apk)
          apk info
          ;;
        homebrew)
          need_cmd brew

          brew list --formula --versions | cut -d ' ' -f 1
          ;;
        mise)
          _discover_mise_global_tools
          ;;
        *)
          warn "unsupported: os=$os; package type=$package_type"
          return 1
          ;;
      esac
      ;;
    arch)
      case "$package_type" in
        aur)
          need_cmd pacman

          # Query for locally-installed packages--this is as close as we can
          # get to looking for AUR packages.
          #
          # See: https://bbs.archlinux.org/viewtopic.php?id=76218
          pacman --query --quiet --foreign
          ;;
        homebrew)
          need_cmd brew

          brew list --formula --versions | cut -d ' ' -f 1
          ;;
        mise)
          _discover_mise_global_tools
          ;;
        pacman)
          need_cmd pacman

          pacman --query --quiet
          ;;
        *)
          warn "unsupported: os=$os; package type=$package_type"
          return 1
          ;;
      esac
      ;;
    bazzite)
      case "$package_type" in
        dnf)
          need_cmd dnf

          dnf list --installed \
            | cut -d ' ' -f 1 \
            | while read -r pkg; do echo "${pkg%.*}"; done
          ;;
        homebrew)
          need_cmd brew

          brew list --formula --versions | cut -d ' ' -f 1
          ;;
        mise)
          _discover_mise_global_tools
          ;;
        *)
          warn "unsupported: os=$os; package type=$package_type"
          return 1
          ;;
      esac
      ;;
    cachyos)
      case "$package_type" in
        aur)
          need_cmd pacman

          # Query for locally-installed packages--this is as close as we can
          # get to looking for AUR packages.
          #
          # See: https://bbs.archlinux.org/viewtopic.php?id=76218
          pacman --query --quiet --foreign
          ;;
        homebrew)
          need_cmd brew

          brew list --formula --versions | cut -d ' ' -f 1
          ;;
        mise)
          _discover_mise_global_tools
          ;;
        pacman)
          need_cmd pacman

          pacman --query --quiet
          ;;
        *)
          warn "unsupported: os=$os; package type=$package_type"
          return 1
          ;;
      esac
      ;;
    debian | truenas | ubuntu)
      case "$package_type" in
        apt)
          need_cmd dpkg-query

          dpkg-query -f '${Package}\n' -W
          ;;
        homebrew)
          need_cmd brew

          brew list --formula --versions | cut -d ' ' -f 1
          ;;
        mise)
          _discover_mise_global_tools
          ;;
        *)
          warn "unsupported: os=$os; package type=$package_type"
          return 1
          ;;
      esac
      ;;
    freebsd)
      case "$package_type" in
        freebsd_pkg)
          need_cmd pkg

          pkg info -q
          ;;
        *)
          warn "unsupported: os=$os; package type=$package_type"
          return 1
          ;;
      esac
      ;;
    macos)
      case "$package_type" in
        homebrew)
          need_cmd brew

          brew list --formula --versions | cut -d ' ' -f 1
          ;;
        homebrew_cask)
          need_cmd brew

          brew list --cask --versions | cut -d ' ' -f 1
          ;;
        mise)
          _discover_mise_global_tools
          ;;
        *)
          warn "unsupported: os=$os; package type=$package_type"
          return 1
          ;;
      esac
      ;;
    openbsd)
      case "$package_type" in
        openbsd_pkg)
          need_cmd pkg_info

          pkg_info -z
          ;;
        *)
          warn "unsupported: os=$os; package type=$package_type"
          return 1
          ;;
      esac
      ;;
    *)
      warn "unsupported: os=$os"
      return 1
      ;;
  esac
}

is_package_installed() {
  local os="$1"
  local package_type="$2"
  local name="$3"
  local installed_cache="${4:-}"

  local installed
  if [ -z "$installed_cache" ]; then
    installed="$installed_cache"
  else
    installed="$(discover_installed_packages "$os" "$package_type")"
  fi

  case "$os" in
    alpine)
      echo "$installed" | grep -q "^${name}-"
      ;;
    arch)
      echo "$installed" | grep -q "^${name}$"
      ;;
    *)
      die "FIXME: unimplemented"
      ;;
  esac
}

# Discovers globally installed Mise tools, emitting `tool@version` strings.
_discover_mise_global_tools() {
  need_cmd mise

  ensure_jq

  (cd / && mise ls --global --json) \
    | jq -r 'to_entries[] | "\(.key)@\(.value[0].requested_version)"'
}
