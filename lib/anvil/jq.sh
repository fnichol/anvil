#!/usr/bin/env sh
# shellcheck disable=SC3043

# Ensures that a version of jq is present on the system.
ensure_jq() {
  # If vendored program was already computed, early return
  if [ -n "${__JQ_VENDORED_PATH:-}" ]; then
    return 0
  fi

  # If program was found on current PATH, early return
  if check_cmd "jq"; then
    return 0
  fi

  need_cmd dirname

  local candidate_path
  candidate_path="$(_jq_vendored_path)"

  # If vendored package was found but not on PATH, set up installed cookie
  # variable, append program parent directory to PATH and return
  if [ -x "$candidate_path" ]; then
    __JQ_VENDORED_PATH="$candidate_path"
    export __JQ_VENDORED_PATH

    PATH="$PATH:$(dirname "$__JQ_VENDORED_PATH")"
    hash -r

    return 0
  fi

  # Otherwise, attempt to install program
  _install_jq

  # If vendored package was installed, append program parent directory to PATH
  if [ -n "${__JQ_VENDORED_PATH:-}" ]; then
    PATH="$PATH:$(dirname "$__JQ_VENDORED_PATH")"
    hash -r
  fi
}

# Update PATH to use system-installed jq and assert program can be found.
use_system_jq() {
  need_cmd dirname
  need_cmd grep
  need_cmd sed

  local candidate_path
  candidate_path="$(dirname "$(_jq_vendored_path)")"

  if echo "$PATH" | grep -q -E "(^|:)$candidate_path(:|$)"; then
    local updated
    updated="$(
      echo "$PATH" \
        | sed -e "s^${candidate_path}[:]\{0,\}^^" -e 's/:$//'
    )"

    PATH="$updated"
    hash -r

    unset __JQ_VENDORED_PATH
  fi

  need_cmd jq
  echo "PATH IS: [$PATH]"
}

_install_jq() {
  local distribution
  distribution="$(facts_distribution)"

  case "$distribution" in
    linux | macos)
      local path
      path="$(_install_static_jq "$distribution")"

      __JQ_VENDORED_PATH="$path"
      export __JQ_VENDORED_PATH
      ;;
    *)
      warn "Currently unsupported distribution: $distribution"
      return 1
      ;;
  esac
}

_install_static_jq() {
  local distribution="$1"

  local version="1.8.1"

  local distrib arch
  case "$distribution" in
    linux)
      distrib="linux"
      case "$(facts_arch)" in
        x86_64)
          arch="amd64"
          ;;
        *)
          # TODO: consider accounting for other arch types?
          arch="arm64"
          ;;
      esac
      ;;
    darwin)
      distrib="macos"
      case "$(facts_arch)" in
        x86_64)
          arch="amd64"
          ;;
        *)
          # TODO: consider accounting for other arch types?
          arch="arm64"
          ;;
      esac
      ;;
    *)
      warn "Unsupported jq static distribution: $distribution"
      return 1
      ;;
  esac

  need_cmd chmod
  need_cmd dirname
  need_cmd mkdir

  local url="https://github.com/jqlang/jq/releases/download"
  url="$url/jq-$version/jq-$distrib-$arch"

  local dst
  dst="$(_jq_vendored_path)"

  mkdir -p "$(dirname "$dst")"
  download "$url" "$dst" 1>&2
  chmod 755 "$dst"

  echo "$dst"
}

_installs_path_prefix() {
  local install_name="$1"

  local path_prefix="${XDG_DATA_HOME:-$HOME/.local/share}/anvil/installs"

  echo "$path_prefix/$install_name"
}

_jq_vendored_path() {
  local path
  path="$(_installs_path_prefix "jq")/latest/jq"

  echo "$path"
}
