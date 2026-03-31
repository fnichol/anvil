#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=/dev/null
. "$ANVIL_HOOK_SUPPORT"

configure_hook_printing() {
  case "$ANVIL_OS" in
    arch | cachyos)
      if ! check_cmd systemctl; then
        info "SystemD not present; skipping"
        return 0
      fi

      for group in lp sys; do
        local group_users
        group_users="$(getent group "$group" | cut -d: -f4 | tr ',' '\n')"

        if ! echo "$group_users" | grep -q "^${USER}$"; then
          info "Adding '$USER' to '$group' group"
          as_root usermod -aG "$group" "$USER"
        fi
      done

      local svc="cups.socket"

      if ! systemctl is-enabled "$svc" >/dev/null; then
        info "Enabling '$svc' service"
        indent as_root systemctl enable "$svc"
      fi
      ;;
  esac
}
