#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/facts.sh
. "$SRC_ROOT/lib/anvil/facts.sh"

facts_steps() {
  local _config_file="$1"
  shift
  local _data_home="$1"
  shift
  local _os="$1"
  shift
  local _version="$1"
  shift
  local _kernel="$1"
  shift
  local _arch="$1"
  shift

  echo "gather"
}

facts_step_gather() {
  __ANVIL_HOSTNAME="$(facts_hostname)"
  __ANVIL_OS="$(facts_os)"
  __ANVIL_VERSION="$(facts_version)"
  __ANVIL_KERNEL="$(facts_kernel)"
  __ANVIL_ARCH="$(facts_arch)"

  indent printf "%-20s %s\n" "Hostname" "$__ANVIL_HOSTNAME"
  indent printf "%-20s %s\n" "Operating System" "$__ANVIL_OS"
  indent printf "%-20s %s\n" "Version" "$__ANVIL_VERSION"
  indent printf "%-20s %s\n" "Kernel" "$__ANVIL_KERNEL"
  indent printf "%-20s %s\n" "Architecture" "$__ANVIL_ARCH"
}
