#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/facts.sh
. "$SRC_ROOT/lib/anvil/facts.sh"
# shellcheck source=lib/anvil/tags.sh
. "$SRC_ROOT/lib/anvil/tags.sh"
# shellcheck source=lib/anvil/discovery.sh
. "$SRC_ROOT/lib/anvil/discovery.sh"
# shellcheck source=lib/anvil/convergence.sh
. "$SRC_ROOT/lib/anvil/convergence.sh"
# shellcheck source=lib/anvil/phases/install.sh
. "$SRC_ROOT/lib/anvil/phases/install.sh"

# Prints usage for the status command.
print_usage_status() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	Show current system state vs desired state

	USAGE:
	    $program status [FLAGS]

	FLAGS:
	    -h, --help       Prints help information

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

# Status command - show current system state vs desired state
cmd_status() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"

  usage() {
    print_usage_status \
      "$program" \
      "$default_config_path" \
      "$default_data_home"
  }

  while [ $# -gt 0 ]; do
    case "$1" in
      # Flags
      -h | --help)
        usage
        return 0
        ;;
      # Parsing
      --) # explicitly terminates argument processing
        shift 1
        break
        ;;
      -?*)
        usage_and_die "invalid argument $1"
        ;;
      *)
        break
        ;;
    esac
  done

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"

  if ! config_exists "$config_file"; then
    warn "No config found at: $config_file"
    warn "Run: $program config init"
    die "Config file not found"
  fi

  need_cmd tr
  need_cmd wc

  section "Anvil Status"

  ensure_jq

  info "Config: $config_file"
  echo ""

  # Show system facts
  section "System"
  local os arch version
  os="$(facts_os)"
  arch="$(facts_arch)"
  version="$(facts_version)"
  info "Operating System: $os"
  info "Architecture: $arch"
  info "Operating System Version: $version"
  echo ""

  # Show configured tags
  section "Configuration"
  local config_roles
  config_roles="$(config_read_roles "$config_file")"
  local config_tags
  config_tags="$(config_read_tags "$config_file")"
  local resolved_tags
  resolved_tags="$(config_resolve_tags "$config_file" "$data_home")"

  if [ -z "$resolved_tags" ]; then
    die "No tags configured. Run: $program config init"
  fi

  info "Roles: $config_roles"
  info "Tags: $config_tags"

  info "Resolved tags (with dependencies): $resolved_tags"
  echo ""

  local pkg_managers
  pkg_managers="$(
    install_steps \
      "$config_file" \
      "$data_home" \
      "$os" \
      "$version" \
      "$(facts_kernel)" \
      "$arch"
  )"

  local total_pending_count
  total_pending_count=0

  local pkg_manager
  for pkg_manager in $pkg_managers; do
    # Show convergence status
    section "Convergence Status ($pkg_manager)"

    local desired_packages
    desired_packages="$(
      desired_packages \
        "$config_file" \
        "$data_home" \
        "$os" \
        "$arch" \
        "$pkg_manager" \
        "$resolved_tags"
    )"
    local desired_count
    desired_count="$(echo "$desired_packages" | wc -l | tr -d ' ')"

    local installed_packages
    installed_packages="$(discover_installed_packages "$os" "$pkg_manager")"
    local installed_count
    installed_count="$(echo "$installed_packages" | wc -l | tr -d ' ')"

    local packages_to_install
    packages_to_install="$(
      convergence_delta "$desired_packages" "$installed_packages"
    )"
    local pending_count
    if [ -n "$packages_to_install" ]; then
      pending_count="$(echo "$packages_to_install" | wc -l | tr -d ' ')"
    else
      pending_count=0
    fi
    total_pending_count=$((total_pending_count + pending_count))

    info "Desired Packages: $desired_count"
    info "Installed Packages: $installed_count"
    info "Pending Installs: $pending_count"
    echo ""
  done

  section "Conclusion"
  if [ "$pending_count" -gt 0 ]; then
    warn "System not converged (pending: $total_pending_count)"
    info "Run: $program apply"
  else
    info "✓ System converged"
  fi
}
