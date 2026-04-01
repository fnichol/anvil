#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=/dev/null
. "$ANVIL_HOOK_SUPPORT"

configure_hook_container_runtime() {
  case "$ANVIL_OS" in
    arch | cachyos)
      local conf="/etc/containers/nodocker"

      if [ ! -f "$conf" ]; then
        info "Disabling Podman warning"
        as_root mkdir -p "$(dirname "$conf")"
        as_root touch "$conf"
      fi
      ;;
  esac
}
