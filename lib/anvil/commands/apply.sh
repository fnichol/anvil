#!/usr/bin/env sh
# shellcheck disable=SC3043

# Prints usage for the apply command.
print_apply_usage() {
  local program="$1"
  local default_config_path="$2"

  cat <<-EOF
	Converge system to desired state

	USAGE:
	    $program apply [FLAGS]

	FLAGS:
	    -h, --help       Prints help information
	    -n, --dry-run    Show what would change without applying

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	EOF
}

# Apply command - converge system to desired state
cmd_apply() {
  local root program
  root="$1"
  shift
  program="$1"
  shift

  . "$root/lib/anvil/config.sh"
  . "$root/lib/anvil/facts.sh"
  . "$root/lib/anvil/tags.sh"
  . "$root/lib/anvil/discovery.sh"
  . "$root/lib/anvil/convergence.sh"

  local default_config_path config_file
  local dry_run=""

  default_config_path="$(config_path)"

  OPTIND=1
  while getopts "hn-:" arg; do
    case "$arg" in
      h)
        print_apply_usage "$program" "$default_config_path"
        return 0
        ;;
      n)
        dry_run=true
        ;;
      -)
        case "$OPTARG" in
          help)
            print_apply_usage "$program" "$default_config_path"
            return 0
            ;;
          dry-run)
            dry_run=true
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_apply_usage "$program" "$default_config_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_apply_usage "$program" "$default_config_path" >&2
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

  section "Anvil Apply"

  # Gather system facts
  section "Discovering system facts..."
  local os arch
  os="$(facts_os)"
  info "Operating system: $os"
  arch="$(facts_arch)"
  info "Architecture: $arch"

  # Read config
  section "Reading configuration..."
  local tags
  tags="$(config_read_tags "$config_file")"
  if [ -z "$tags" ]; then
    die "No tags configured. Run: $program config init"
  fi
  info "Configured tags: $tags"

  # Resolve tag dependencies
  section "Resolving tag dependencies..."
  local resolved_tags
  resolved_tags="$(tags_resolve "$root" "$tags")"
  info "Resolved tags (with dependencies): $resolved_tags"

  # Build desired package list
  section "Building desired package list..."
  local desired_packages
  desired_packages="$(
    desired_packages "$root" "$os" "$arch" "homebrew" "$resolved_tags"
  )"
  local desired_count
  desired_count="$(echo "$desired_packages" | wc -l | tr -d ' ')"
  info "Desired packages: $desired_count"

  # Discover installed packages
  section "Discovering installed packages..."
  local installed_packages
  installed_packages="$(
    discover_installed_packages "$os" "homebrew"
  )"
  local installed_count
  installed_count="$(echo "$installed_packages" | wc -l | tr -d ' ')"
  info "Currently installed: $installed_count"

  # Calculate delta
  section "Calculating changes..."
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

  # Show results
  if [ "$pending_count" -eq 0 ]; then
    section "System Converged"
    info "No changes needed - system is already in desired state"
    return 0
  fi

  if [ -n "$dry_run" ]; then
    section "Dry Run - Would Install ($pending_count packages)"
    echo "$packages_to_install" | while IFS= read -r pkg; do
      if [ -n "$pkg" ]; then
        indent echo "+ $pkg"
      fi
    done
    echo ""
    info "Run without --dry-run to apply changes"
  else
    section "Installing Packages ($pending_count packages)"

    # Ensure package manager is set up
    case "$os" in
      macos)
        . "$root/lib/common.sh"
        . "$root/lib/unix.sh"
        . "$root/lib/darwin.sh"
        info "Setting up package system..."

        case "$arch" in
          aarch64)
            _arch="arm64"
            ;;
          *)
            _arch="$arch"
            ;;
        esac
        darwin_setup_package_system
        unset _arch
        ;;
      *)
        die "Platform not yet supported: $os"
        ;;
    esac

    # Install packages
    install_packages "$root" "$os" "$packages_to_install"

    section "Apply Complete"
    info "Successfully installed $pending_count packages"
  fi
}
