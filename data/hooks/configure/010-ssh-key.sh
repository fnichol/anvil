#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=/dev/null
. "$ANVIL_HOOK_SUPPORT"

configure_hook_ssh_key() {
  if ! check_cmd ssh-keygen; then
    info "No SSH client detected; skipping"
    return 0
  fi

  local key="$HOME/.ssh/id_ed25519"

  if [ ! -f "$key" ]; then
    info "Generating SSH key for '$USER' on $ANVIL_HOSTNAME"

    mkdir -p "$(dirname "$key")"

    indent ssh-keygen \
      -N '' \
      -C "${USER}@${ANVIL_HOSTNAME}-$(date -u +%FT%TZ)" \
      -t ed25519 \
      -a 100 \
      -f "$key"

    chmod 0700 "$(dirname "$key")"
    chmod 0600 "$key"
    chmod 0644 "$key.pub"
  fi
}
