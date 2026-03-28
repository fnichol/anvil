#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
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

# Prints usage for the status command.
print_usage_status() {
  local program="$1"
  local default_config_path="$2"

  cat <<-EOF
	Show current system state vs desired state

	USAGE:
	    $program status [FLAGS]

	FLAGS:
	    -h, --help       Prints help information

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	EOF
}

# Status command - show current system state vs desired state
cmd_status() {
  local root program
  root="$1"
  shift
  program="$1"
  shift

  local default_config_path config_file

  default_config_path="$(config_path)"

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_status "$program" "$default_config_path"
        return 0
        ;;
      -)
        case "$OPTARG" in
          help)
            print_usage_status "$program" "$default_config_path"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_status "$program" "$default_config_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_status "$program" "$default_config_path" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"

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
  local resolved_tags
  resolved_tags="$(config_resolve_tags "$root" "$config_file")"

  if [ -z "$resolved_tags" ]; then
    die "No tags configured. Run: $program config init"
  fi

  info "Tags: $resolved_tags"

  info "Resolved (with dependencies): $resolved_tags"
  echo ""

  # Show convergence status
  section "Convergence Status"

  local desired_packages
  desired_packages="$(
    desired_packages "$root" "$os" "$arch" "homebrew" "$resolved_tags"
  )"
  local desired_count
  desired_count="$(echo "$desired_packages" | wc -l | tr -d ' ')"

  local installed_packages
  installed_packages="$(discover_installed_packages "$os" "homebrew")"
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

  info "Desired Packages: $desired_count"
  info "Installed Packages: $installed_count"
  info "Pending Installs: $pending_count"
  echo ""

  section "Conclusion"
  if [ "$pending_count" -gt 0 ]; then
    warn "System not converged"
    info "Run: $program apply"
  else
    info "✓ System converged"
  fi
}
