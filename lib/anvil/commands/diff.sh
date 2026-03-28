#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/facts.sh
. "$SRC_ROOT/lib/anvil/facts.sh"
# shellcheck source=lib/anvil/discovery.sh
. "$SRC_ROOT/lib/anvil/discovery.sh"
# shellcheck source=lib/anvil/convergence.sh
. "$SRC_ROOT/lib/anvil/convergence.sh"

# Prints usage for the diff command.
print_usage_diff() {
  local program="$1"
  local default_config_path="$2"

  cat <<-EOF
	Show what would change if apply was run

	USAGE:
	    $program diff [FLAGS]

	FLAGS:
	    -h, --help       Prints help information

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	EOF
}

# Diff command - show what would change
cmd_diff() {
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
        print_usage_diff "$program" "$default_config_path"
        return 0
        ;;
      -)
        case "$OPTARG" in
          help)
            print_usage_diff "$program" "$default_config_path"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_diff "$program" "$default_config_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_diff "$program" "$default_config_path" >&2
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

  section "Anvil Diff"

  # Gather info
  local os arch resolved_tags
  os="$(facts_os)"
  arch="$(facts_arch)"
  resolved_tags="$(config_resolve_tags "$root" "$config_file")"

  if [ -z "$resolved_tags" ]; then
    die "No tags configured. Run: $program config init"
  fi

  # Calculate diff
  local desired_packages installed_packages packages_to_install
  desired_packages="$(
    desired_packages "$root" "$os" "$arch" "homebrew" "$resolved_tags"
  )"
  installed_packages="$(discover_installed_packages "$os" "homebrew")"
  packages_to_install="$(
    convergence_delta "$desired_packages" "$installed_packages"
  )"

  # Show what would change
  local pkg_count
  if [ -n "$packages_to_install" ]; then
    pkg_count="$(echo "$packages_to_install" | wc -l | tr -d ' ')"
  else
    pkg_count=0
  fi

  if [ "$pkg_count" -eq 0 ]; then
    info "No changes needed - system is converged"
  else
    section "Packages to Install ($pkg_count)"
    echo "$packages_to_install" | while IFS= read -r pkg; do
      if [ -n "$pkg" ]; then
        indent echo "+ $pkg"
      fi
    done
  fi
}
