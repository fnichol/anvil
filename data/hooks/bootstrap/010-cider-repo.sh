#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=/dev/null
. "$ANVIL_HOOK_SUPPORT"

bootstrap_hook_cider_repo() {
  case "$ANVIL_OS" in
    # See: https://repo.cider.sh/
    arch | cachyos)
      if ! grep -q '^\[cidercollective\]$' /etc/pacman.conf; then
        need_cmd pacman-key

        local gpg_key
        gpg_key="$(mktemp_file)"
        cleanup_file "$gpg_key"

        download https://repo.cider.sh/ARCH-GPG-KEY "$gpg_key"

        info "Importing Cider Collective GPG key"
        ident as_root pacman-key --add - <"$gpg_key"
        ident as_root pacman-key --lsign-key A0CD6B993438E22634450CDD2A236C3F42A61682

        info "Adding Cider Collective repository"
        as_root tee -a /etc/pacman.conf <<-'EOF' >/dev/null
	
		# Cider Collective Repository
		[cidercollective]
		SigLevel = Required TrustedOnly
		Server = https://repo.cider.sh/arch
		EOF
      fi
      ;;
  esac
}
