#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=/dev/null
. "$ANVIL_HOOK_SUPPORT"

configure_hook_virtualization() {
  case "$ANVIL_OS" in
    # See: https://wiki.cachyos.org/virtualization/qemu_and_vmm_setup/
    arch | cachyos)
      local conf="/etc/libvirt/network.conf"

      if ! grep -q '^firewall_backend = "iptables"$' "$conf"; then
        info "Configuring libvirt to use iptables"
        echo 'firewall_backend = "iptables"' | as_root tee -a "$conf" >/dev/null

        info "Enabling network autostart whenever a VM is started"
        as_root virsh net-autostart default
      fi

      local svc
      for svc in libvirtd.service libvirtd.socket; do
        if ! systemctl is-enabled "$svc" >/dev/null; then
          info "Enabling and starting '$svc' service"
          indent as_root systemctl enable --now "$svc"
        fi
      done

      local group group_users
      group="libvirt"
      group_users="$(getent group "$group" | cut -d: -f4 | tr ',' '\n')"

      if ! echo "$group_users" | grep -q "^${USER}$"; then
        info "Adding '$USER' to '$group' group"
        as_root usermod -aG "$group" "$USER"
      fi

      if ! as_root ufw status | grep -q '^Anywhere\s*ALLOW FWD\s*192\.168\.122\.0/24$'; then
        info "Enabling the entire VM network to have unfettered transit"
        sudo ufw route allow from 192.168.122.0/24
      fi
      ;;
  esac
}
