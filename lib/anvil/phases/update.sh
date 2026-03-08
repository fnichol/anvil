#!/usr/bin/env sh
# shellcheck disable=SC3043

update_steps() {
  echo "system_packages"
}

update_step_system_packages() {
  # TODO: update package index and upgrade installed packages.
  #
  # Dispatches to the correct package manager internally based on $__ANVIL_OS.

  info "update:system_packages - stub"
}
