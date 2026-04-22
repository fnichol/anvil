#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"

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
  local default_moduless_lock_path modules_lock_file
  default_moduless_lock_path="$(modules_lock_path)"

  local name

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_module_remove "$program" \
          "$default_config_path" "$default_data_home" \
          "$default_moduless_lock_path"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_module_remove "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_module_remove "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_module_remove "$program" \
          "$default_config_path" "$default_data_home" \
          "$default_moduless_lock_path" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  if [ -n "${1:-}" ]; then
    name="$1"
  else
    print_usage_module_remove "$program" \
      "$default_config_path" "$default_data_home" \
      "$default_moduless_lock_path" >&2
    die "required argument: NAME"
  fi

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"
  modules_lock_file="${ANVIL_MODULES_LOCK_PATH:-$default_moduless_lock_path}"

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
