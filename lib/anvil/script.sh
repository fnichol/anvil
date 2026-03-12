#!/usr/bin/env sh
# shellcheck disable=SC3043

# Ensures that a version of Busybox with script applet is present on the Linux system.
ensure_script() {
  local kernel
  kernel="$(facts_kernel)"

  # Early return is system is not Linux
  if [ "$kernel" != "linux" ]; then
    return 0
  fi

  # If vendored program was already computed, early return
  if [ -n "${__BUSYBOX_VENDORED_PATH:-}" ]; then
    return 0
  fi

  # If script was found on current PATH, early return
  if check_cmd script; then
    return 0
  fi

  # If program was found on current PATH and has script applet, early return
  if check_cmd "busybox" && busybox --list | grep -q -x script; then
    return 0
  fi

  need_cmd dirname

  local candidate_path
  candidate_path="$(_busybox_vendored_latest_path)"

  # If vendored package was found but not on PATH, set up installed cookie
  # variable, append program parent directory to PATH and return
  if [ -x "$candidate_path" ]; then
    __BUSYBOX_VENDORED_PATH="$candidate_path"
    export __BUSYBOX_VENDORED_PATH

    PATH="$PATH:$(dirname "$__BUSYBOX_VENDORED_PATH")"
    hash -r

    return 0
  fi

  # Otherwise, attempt to install program
  _install_busybox_with_script

  # If vendored package was installed, append program parent directory to PATH
  if [ -n "${__BUSYBOX_VENDORED_PATH:-}" ]; then
    PATH="$PATH:$(dirname "$__BUSYBOX_VENDORED_PATH")"
    hash -r
  fi
}

_install_busybox_with_script() {
  local kernel
  kernel="$(facts_kernel)"

  case "$kernel" in
    linux)
      local path
      path="$(_install_static_busybox_with_script)"

      __BUSYBOX_VENDORED_PATH="$path"
      export __BUSYBOX_VENDORED_PATH
      ;;
    *)
      warn "Currently unsupported distribution: $kernel"
      return 1
      ;;
  esac
}

_install_static_busybox_with_script() {
  local version="1.31.0"

  local arch
  case "$(facts_arch)" in
    x86_64)
      arch="x86_64"
      ;;
    *)
      # TODO: consider accounting for other arch types?
      arch="armv7r"
      ;;
  esac

  need_cmd chmod
  need_cmd dirname
  need_cmd ln
  need_cmd mkdir

  local url="https://busybox.net/downloads/binaries/$version-defconfig-multiarch-musl"
  url="$url/busybox-$arch"

  local dst
  dst="$(_installs_path_prefix "busybox")/$version/busybox"

  local latest
  latest="$(_busybox_vendored_latest_path)"

  mkdir -p "$(dirname "$dst")"
  download "$url" "$dst" 1>&2
  chmod 755 "$dst"
  ln -snf "./$version" "$(dirname "$latest")"

  ln -snf "./busybox" "$(dirname "$latest")/script"

  echo "$latest"
}

_installs_path_prefix() {
  local install_name="$1"

  local path_prefix="${XDG_DATA_HOME:-$HOME/.local/share}/anvil/installs"

  echo "$path_prefix/$install_name"
}

_busybox_vendored_latest_path() {
  local path
  path="$(_installs_path_prefix "busybox")/latest/busybox"

  echo "$path"
}
