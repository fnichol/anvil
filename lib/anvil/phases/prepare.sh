#!/usr/bin/env sh
# shellcheck disable=SC3043

prepare_steps() {
  echo "hostname"
}

prepare_step_hostname() {
  local root="$1"
  shift
  local config_path="$1"
  shift
  local hostname="$1"
  shift
  local os="$1"
  shift

  # shellcheck source=lib/anvil/jq.sh
  . "$root/lib/anvil/jq.sh"
  # shellcheck source=lib/anvil/config.sh
  . "$root/lib/anvil/config.sh"
  # shellcheck source=lib/anvil/facts.sh
  . "$root/lib/anvil/facts.sh"

  local fqdn
  fqdn="$(config_read_fqdn "$config_path")"

  # If no FQDN is configured, early return
  if [ -z "$fqdn" ]; then
    return 0
  fi

  local current_fqdn="$hostname"

  # If Already matches; idempotent no-op
  if [ "$current_fqdn" = "$fqdn" ]; then
    return 0
  fi

  info "Setting hostname: $current_fqdn → $fqdn"

  # **Note**: `truenas` is omitted as it's easier to update hostname via web UI
  case "$os" in
    alpine)
      need_cmd hostname
      need_cmd tee

      echo "$fqdn" | sudo tee /etc/hostname >/dev/null
      sudo hostname -F /etc/hostname \
        || warn "Failed to update hostname to '$fqdn'; continuing"
      ;;
    arch | bazzite | cachyos | debian | ubuntu)
      need_cmd sed
      need_cmd tee

      echo "$fqdn" | sudo tee /etc/hostname >/dev/null

      if check_cmd hostnamectl; then
        sudo hostnamectl set-hostname "$fqdn" \
          || warn "Failed to update hostname to '$fqdn'; continuing"
      elif check_cmd hostname; then
        sudo hostname -F /etc/hostname \
          || warn "Failed to update hostname to '$fqdn'; continuing"
      fi

      if ! grep -q -w "$fqdn" /etc/hosts; then
        sudo sed -i "1i 127.0.0.1\\t${fqdn}\\t${fqdn%%.*}" /etc/hosts
      fi
      ;;
    freebsd)
      need_cmd hostname

      hostname "$fqdn" \
        || warn "Failed to update hostname to '$fqdn'; continuing"
      ;;
    macos)
      need_cmd scutil

      sudo scutil --set HostName "$fqdn" \
        || warn "Failed to update HostName to '$fqdn'; continuing"
      sudo scutil --set LocalHostName "${fqdn%%.*}" \
        || warn "Failed to update LocalHostName to '${fqdn%%.*}'; continuing"
      sudo scutil --set ComputerName "${fqdn%%.*}" \
        || warn "Failed to update ComputerName to '${fqdn%%.*}'; continuing"
      ;;
    openbsd)
      need_cmd hostname
      need_cmd tee

      echo "$fqdn" | doas tee /etc/myname >/dev/null
      doas hostname "$fqdn" \
        || warn "Failed to update hostname to '$fqdn'; continuing"
      ;;
    *)
      warn "Unsupported OS '$os'; skipping"
      return 0
      ;;
  esac

  # Set global variable so next step can use updated value
  __ANVIL_HOSTNAME="$fqdn"
}
