#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/facts.sh
. "$SRC_ROOT/lib/anvil/facts.sh"
# shellcheck source=lib/anvil/discovery.sh
. "$SRC_ROOT/lib/anvil/discovery.sh"
# shellcheck source=lib/anvil/convergence.sh
. "$SRC_ROOT/lib/anvil/convergence.sh"
# shellcheck source=lib/anvil/phases/install.sh
. "$SRC_ROOT/lib/anvil/phases/install.sh"

print_usage_diff() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	Show what would change if apply was run

	USAGE:
	    $program diff [FLAGS]

	FLAGS:
	    -h, --help       Prints help information

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

cmd_diff() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"

  usage() {
    print_usage_diff \
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

  section "Anvil Diff"

  # Gather info
  local os arch resolved_tags
  os="$(facts_os)"
  arch="$(facts_arch)"
  resolved_tags="$(config_resolve_tags "$config_file" "$data_home")"

  if [ -z "$resolved_tags" ]; then
    die "No tags configured. Run: $program config init"
  fi

  local pkg_managers
  pkg_managers="$(
    install_steps \
      "$config_file" \
      "$data_home" \
      "$os" \
      "$(facts_version)" \
      "$(facts_kernel)" \
      "$arch"
  )"

  local pkg_manager
  for pkg_manager in $pkg_managers; do
    # Calculate diff
    local desired_packages installed_packages packages_to_install
    desired_packages="$(
      desired_packages \
        "$config_file" \
        "$data_home" \
        "$os" \
        "$arch" \
        "$pkg_manager" \
        "$resolved_tags"
    )"
    installed_packages="$(discover_installed_packages "$os" "$pkg_manager")"
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
      info "No changes needed - system is converged ($pkg_manager)"
    else
      section "Packages to Install ($pkg_manager: $pkg_count)"
      echo "$packages_to_install" | while IFS= read -r pkg; do
        if [ -n "$pkg" ]; then
          indent echo "+ $pkg"
        fi
      done
    fi
  done
}
