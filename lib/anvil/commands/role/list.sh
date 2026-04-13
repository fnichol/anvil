#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/roles.sh
. "$SRC_ROOT/lib/anvil/roles.sh"

print_usage_role_list() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	List all available roles
	
	USAGE:
	    $program role list [FLAGS]
	
	FLAGS:
	    -h, --help              Prints help information

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

cmd_role_list() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_role_list "$program" \
          "$default_config_path" "$default_data_home"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_role_list "$program" \
              "$default_config_path" "$default_data_home"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_role_list "$program" \
              "$default_config_path" "$default_data_home" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_role_list "$program" \
          "$default_config_path" "$default_data_home" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"

  ensure_jq

  need_cmd basename
  need_cmd ls

  section "Available Roles"

  roles_list_all "$config_file" "$data_home" | while IFS= read -r role; do
    local role_file
    role_file="$(roles_path_for "$config_file" "$data_home" "$role")"

    local desc
    desc="$(jq -r '.description // "No description"' "$role_file")"

    printf "  %-20s %s\n" "$role" "$desc"
  done
}
