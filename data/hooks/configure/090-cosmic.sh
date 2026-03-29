#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=/dev/null
. "$ANVIL_HOOK_SUPPORT"

configure_hook_cosmic() {
  case "$ANVIL_OS" in
    # See: https://wiki.archlinux.org/title/GNOME/Keyring
    arch | cachyos)
      if ! grep -q 'pam_gnome_keyring.so auto_start$' /etc/pam.d/login; then
        need_cmd awk
        need_cmd install

        local tmp_login
        tmp_login="$(mktemp_file)"
        cleanup_file "$tmp_login"

        info "Starting gnome-keyring in PAM at console login"
        awk '
          /^auth *include *system-local-login$/ {
            print
            print "auth       optional     pam_gnome_keyring.so"
            next
          }
          /^session *include *system-local-login$/ {
            print
            print "session    optional     pam_gnome_keyring.so auto_start"
            next
          }
          { print }
        ' /etc/pam.d/login >"$tmp_login"
        as_root install -m 644 -o root -g root "$tmp_login" /etc/pam.d/login
      fi

      if ! grep -q 'pam_gnome_keyring.so$' /etc/pam.d/passwd; then
        need_cmd awk
        need_cmd tee

        info "Configure to change keyring password with user password"
        echo "password	optional	pam_gnome_keyring.so" \
          | as_root tee -a /etc/pam.d/passwd >/dev/null
      fi
      ;;
  esac
}
