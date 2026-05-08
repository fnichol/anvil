#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"

print_usage_module_remove() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"
  local default_modules_lock_path="$4"

  cat <<-EOF
	Remove a module

	USAGE:
	    $program module remove [FLAGS] <NAME>

	FLAGS:
	    -h, --help              Prints help information

	ARGUMENTS:
	    <NAME>                  Module name alias

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	    ANVIL_MODULES_LOCK_PATH [default: $default_modules_lock_path]
	EOF
}

cmd_module_remove() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"
  local default_modules_lock_path modules_lock_file
  default_modules_lock_path="$(modules_lock_path)"

  usage() {
    print_usage_module_remove \
      "$program" \
      "$default_config_path" \
      "$default_data_home" \
      "$default_modules_lock_path"
  }

  local name

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

  if [ -n "${1:-}" ]; then
    name="$1"
  else
    usage_and_die "required argument: NAME"
  fi

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"
  modules_lock_file="${ANVIL_MODULES_LOCK_PATH:-$default_modules_lock_path}"

  if ! config_exists "$config_file"; then
    warn "No config found at: $config_file"
    warn "Run: $program config init"
    die "Config file not found"
  fi

  # Confirm named module is registered
  if ! modules_installed_names "$config_file" "$data_home" \
    | grep -q "^$name$"; then
    die "Module named '$name' is not present. Run 'anvil module list'"
  fi

  local mod_path
  mod_path="$(module_path_for "$data_home" "$name")"

  section "Removing module $name"

  module_config_remove_for \
    "$config_file" \
    "$name"

  module_lock_remove_for \
    "$modules_lock_file" \
    "$name"

  module_uninstall "$mod_path"
}
