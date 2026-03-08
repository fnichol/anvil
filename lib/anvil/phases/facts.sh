#!/usr/bin/env sh
# shellcheck disable=SC3043

facts_steps() {
  echo "gather"
}

facts_step_gather() {
  local root="$1"

  # shellcheck source=lib/anvil/facts.sh
  . "$root/lib/anvil/facts.sh"

  __ANVIL_HOSTNAME="$(facts_hostname)"
  __ANVIL_OS="$(facts_os)"
  __ANVIL_VERSION="$(facts_version)"
  __ANVIL_KERNEL="$(facts_kernel)"
  __ANVIL_ARCH="$(facts_arch)"

  info "  Hostname:                 $__ANVIL_HOSTNAME"
  info "  Operating System:         $__ANVIL_OS"
  info "  Operating System Version: $__ANVIL_VERSION"
  info "  Kernel:                   $__ANVIL_DISTRIBUTION"
  info "  Architecture:             $__ANVIL_ARCH"
}
