#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/convergence.sh
. "$SRC_ROOT/lib/anvil/convergence.sh"
# shellcheck source=lib/anvil/discovery.sh
. "$SRC_ROOT/lib/anvil/discovery.sh"

# Returns platform-specific install steps, one package manager per step.
install_steps() {
  local config_file="$1"
  shift
  local data_home="$1"
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
    _steps_extra_package_managers "$config_file" "$data_home" "$os" "$arch"
  )"

  # Native system package managers installs are first and unconditional
  case "$os" in
    alpine)
      echo "apk"
      ;;
    arch | cachyos)
      echo "pacman"
      ;;
    debian | ubuntu)
      echo "apt"
      ;;
    freebsd)
      echo "freebsd_pkg"
      ;;
    openbsd)
      echo "openbsd_pkg"
      ;;
  esac

  # Extra package managers installs only when tags declare them
  if echo "$extra_managers" | grep -q "^aur$"; then
    echo "aur"
  fi

  if echo "$extra_managers" | grep -q "^homebrew$"; then
    echo "homebrew"
    if [ "$os" = "macos" ]; then
      echo "homebrew_cask"
    fi
  fi

  if echo "$extra_managers" | grep -q "^homeshick$"; then
    echo "homeshick"
  fi

  # Mise is only installed on Linux and macOS systems (not on BSD systems)
  case "$os" in
    freebsd | openbsd) ;;
    *)
      if echo "$extra_managers" | grep -q "^mise$"; then
        echo "mise"
      fi
      ;;
  esac
}

install_step_apk() {
  local root="$1"
  shift
  local config_path="$1"
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

  local package_type="apk"

  _install_step_packages "$root" "$config_path" "$os" "$arch" "$package_type"
}

install_step_apt() {
  local root="$1"
  shift
  local config_path="$1"
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

  local package_type="apt"

  _install_step_packages "$root" "$config_path" "$os" "$arch" "$package_type"
}

install_step_aur() {
  local root="$1"
  shift
  local config_path="$1"
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

  local package_type="aur"

  _install_step_packages "$root" "$config_path" "$os" "$arch" "$package_type"
}

install_step_homebrew() {
  local root="$1"
  shift
  local config_path="$1"
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

  _install_step_packages "$root" "$config_path" "$os" "$arch" "$package_type"
}

install_step_homebrew_cask() {
  local root="$1"
  shift
  local config_path="$1"
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

  local package_type="homebrew_cask"

  _install_step_packages "$root" "$config_path" "$os" "$arch" "$package_type"
}

install_step_homeshick() {
  local root="$1"
  shift
  local config_path="$1"
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

  local package_type="homeshick"

  local resolved_tags
  resolved_tags="$(config_resolve_tags "$root" "$config_path")"

  # No tags are configured, early return
  if [ -z "$resolved_tags" ]; then
    return 0
  fi

  local desired
  desired="$(
    desired_packages "$root" "$os" "$arch" "$package_type" "$resolved_tags"
  )"

  # If no castles are found desired, early return
  if [ -z "$desired" ]; then
    return 0
  fi

  local castle repo_name
  for castle in $desired; do
    repo_name="${castle##*/}"

    if [ ! -d "$HOME/.homesick/repos/$repo_name" ]; then
      homeshick --batch clone "$castle"
      homeshick --batch link "$repo_name"
    fi
  done
}

install_step_mise() {
  local root="$1"
  shift
  local config_path="$1"
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

  local package_type="mise"

  _install_step_packages "$root" "$config_path" "$os" "$arch" "$package_type"
}

install_step_pacman() {
  local root="$1"
  shift
  local config_path="$1"
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

  local package_type="pacman"

  _install_step_packages "$root" "$config_path" "$os" "$arch" "$package_type"
}

install_step_freebsd_pkg() {
  local root="$1"
  shift
  local config_path="$1"
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

  local package_type="freebsd_pkg"

  _install_step_packages "$root" "$config_path" "$os" "$arch" "$package_type"
}

install_step_openbsd_pkg() {
  local root="$1"
  shift
  local config_path="$1"
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

  local package_type="openbsd_pkg"

  _install_step_packages "$root" "$config_path" "$os" "$arch" "$package_type"
}

# Common package installation using convergence.
#
# Reads desired packages from config tags, discovers installed packages,
# computes the delta, and dispatches to the appropriate
# `_install_packages_<type>` function if any packages need installing.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String]` operating system (e.g. "macos", "arch")
# * `@param [String]` architecture (e.g. "x86_64", "aarch64")
# * `@param [String]` package type (e.g. "homebrew", "pacman", "apt")
# * `@return 0` if successful
_install_step_packages() {
  local config_file="$1"
  local data_home="$2"
  local os="$3"
  local arch="$4"
  local package_type="$5"

  need_cmd tr
  need_cmd wc

  local resolved_tags
  resolved_tags="$(config_resolve_tags "$config_file" "$data_home")"

  # No tags are configured, early return
  if [ -z "$resolved_tags" ]; then
    return 0
  fi

  local desired
  desired="$(
    desired_packages "$root" "$os" "$arch" "$package_type" "$resolved_tags"
  )"
  desired="$(
    _normalize_packages "$root" "$os" "$arch" "$package_type" "$desired"
  )"

  # If no packages are found desired, early return
  if [ -z "$desired" ]; then
    return 0
  fi

  local installed
  installed="$(discover_installed_packages "$os" "$package_type")"

  local to_install
  to_install="$(convergence_delta "$desired" "$installed")"

  if [ -z "$to_install" ]; then
    info "[install:$package_type] System is already in desired state"
    return 0
  fi

  local pending_count
  pending_count="$(echo "$to_install" | wc -l | tr -d ' ')"
  info "[install:$package_type] Packages to install: $pending_count"

  "_install_packages_${package_type}" "$to_install"
}

# Installs a list of Apk packages.
#
# * `@param [String]` newline-delimited package list
_install_packages_apk() {
  local packages="$1"

  need_cmd apk

  local total current
  total="$(echo "$packages" | grep -c . || echo 0)"
  current=0

  echo "$packages" | while IFS= read -r pkg; do
    if [ -n "$pkg" ]; then
      current=$((current + 1))
      info "[$current/$total] Installing: $pkg"
      indent as_root apk add "$pkg"
    fi
  done
}

# Installs a list of Apt packages.
#
# * `@param [String]` newline-delimited package list
_install_packages_apt() {
  local packages="$1"

  need_cmd apt-get

  local total current
  total="$(echo "$packages" | grep -c . || echo 0)"
  current=0

  echo "$packages" | while IFS= read -r pkg; do
    if [ -n "$pkg" ]; then
      current=$((current + 1))
      info "[$current/$total] Installing: $pkg"
      indent as_root env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y "$pkg"
    fi
  done
}
# Installs a list of AUR packages via Paru.
#
# * `@param [String]` newline-delimited package list
_install_packages_aur() {
  local packages="$1"

  need_cmd paru

  local total
  total="$(echo "$packages" | grep -c . || echo 0)"

  if [ -n "$packages" ]; then
    info "[$total/$total] Installing: $(echo "$packages" | tr '\n' ' ')"
    # shellcheck disable=SC2086
    indent paru -S --needed --noconfirm $packages
  fi
}

# Installs a list of Homebrew formulae.
#
# * `@param [String]` newline-delimited package list
_install_packages_homebrew() {
  local packages="$1"

  need_cmd brew

  local total current
  total="$(echo "$packages" | grep -c . || echo 0)"
  current=0

  echo "$packages" | while IFS= read -r pkg; do
    if [ -n "$pkg" ]; then
      current=$((current + 1))
      info "[$current/$total] Installing: $pkg"
      indent env HOMEBREW_NO_AUTO_UPDATE=true \
        brew install "$pkg" </dev/null
    fi
  done
}

# Installs a list of Homebrew casks.
#
# * `@param [String]` newline-delimited package list
_install_packages_homebrew_cask() {
  local packages="$1"

  need_cmd brew

  local total current
  total="$(echo "$packages" | grep -c . || echo 0)"
  current=0

  echo "$packages" | while IFS= read -r pkg; do
    if [ -n "$pkg" ]; then
      current=$((current + 1))
      info "[$current/$total] Installing: $pkg"
      indent env HOMEBREW_NO_AUTO_UPDATE=true \
        brew install --cask "$pkg" </dev/null
    fi
  done
}

# Installs a list of Mise global tools.
#
# * `@param [String]` newline-delimited tool@version list
_install_packages_mise() {
  local packages="$1"

  need_cmd mise

  local total current
  total="$(echo "$packages" | grep -c . || echo 0)"
  current=0

  echo "$packages" | while IFS= read -r pkg; do
    if [ -n "$pkg" ]; then
      current=$((current + 1))
      info "[$current/$total] Installing: $pkg"
      # **NOTE**: Ensure that current directory isn't a project with its own
      # local Mise configuration.
      (cd / && indent mise use --global "$pkg")
    fi
  done
}

# Installs a list of Pacman system packages.
#
# * `@param [String]` newline-delimited package list
_install_packages_pacman() {
  local packages="$1"

  need_cmd pacman

  local total
  total="$(echo "$packages" | grep -c . || echo 0)"

  if [ -n "$packages" ]; then
    info "[$total/$total] Installing: $(echo "$packages" | tr '\n' ' ')"
    # shellcheck disable=SC2086
    indent as_root pacman -S --needed --noconfirm $packages
  fi
}

# Installs a list of FreeBSD Pkg packages.
#
# * `@param [String]` newline-delimited package list
_install_packages_freebsd_pkg() {
  local packages="$1"

  need_cmd pkg

  local total current
  total="$(echo "$packages" | grep -c . || echo 0)"
  current=0

  echo "$packages" | while IFS= read -r pkg; do
    if [ -n "$pkg" ]; then
      current=$((current + 1))
      info "[$current/$total] Installing: $pkg"
      indent as_root pkg install --yes --no-repo-update "$pkg"
    fi
  done
}

# Installs a list of OpenBSD Pkg packages.
#
# * `@param [String]` newline-delimited package list
_install_packages_openbsd_pkg() {
  local packages="$1"

  need_cmd pkg_add

  local total current
  total="$(echo "$packages" | grep -c . || echo 0)"
  current=0

  echo "$packages" | while IFS= read -r pkg; do
    if [ -n "$pkg" ]; then
      current=$((current + 1))
      info "[$current/$total] Installing: $pkg"
      indent as_root pkg_add -Iv "$pkg"
    fi
  done
}

_normalize_packages() {
  local _root="$1"
  local _os="$2"
  local _arch="$3"
  local package_type="$4"
  local pkgs="$5"

  case "$package_type" in
    mise)
      local normalized_pkgs pkg
      normalized_pkgs=""

      for pkg in $pkgs; do
        case "$pkg" in
          *@*)
            # do nothing, version already present
            ;;
          *)
            # no version, default normalized form to `@latest`
            pkg="$pkg@latest"
            ;;
        esac

        normalized_pkgs="$normalized_pkgs${normalized_pkgs:+
}$pkg"
      done

      echo "$normalized_pkgs"
      ;;
    pacman)
      # Get list of all possible package groups
      local pkg_groups
      pkg_groups="$(pacman -Sg)"

      local pkg_set
      pkg_set="$(mktemp_file)"
      cleanup_file "$pkg_set"

      for pkg in $pkgs; do
        if echo "$pkg_groups" | grep -q "^${pkg}$"; then
          # Expand group into individual package entries
          pacman -Sg "$pkg" | cut -d ' ' -f 2 >>"$pkg_set"
        else
          echo "$pkg" >>"$pkg_set"
        fi
      done

      sort -u "$pkg_set"
      ;;
    *)
      echo "$pkgs"
      ;;
  esac
}
