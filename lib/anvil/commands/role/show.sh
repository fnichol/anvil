#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"

print_usage_role_show() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	Show details of a role
	
	USAGE:
	    $program role show [FLAGS] <NAME>
	
	FLAGS:
	    -h, --help              Prints help information

	ARGUMENTS:
	    <NAME>                  Name of the role

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

cmd_role_show() {
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
        print_usage_role_show "$program" \
          "$default_config_path" "$default_data_home"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_role_show "$program" \
              "$default_config_path" "$default_data_home"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_role_show "$program" \
              "$default_config_path" "$default_data_home" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_role_show "$program" \
          "$default_config_path" "$default_data_home" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  if [ -n "${1:-}" ]; then
    name="$1"
  else
    print_usage_role_show "$program" \
      "$default_config_path" "$default_data_home" >&2
    die "required argument: NAME"
  fi

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"

  local role_file
  role_file="$(roles_path_for "$config_file" "$data_home" "$name")"

  if [ ! -f "$role_file" ]; then
    die "Role not found: $name"
  fi

  ensure_jq

  section "Role: $name"

  # Show description
  local desc
  desc="$(jq -r '.description // "No description"' "$role_file")"
  echo "Description: $desc"
  echo ""

  # Show dependencies
  local deps
  deps="$(jq -r '.depends_on[]? // empty' "$role_file")"

  if [ -n "$deps" ]; then
    echo "Dependencies:"
    echo "$deps" | while IFS= read -r dep; do
      echo "  - $dep"
    done
    echo ""
  fi

  # Show tags
  echo "Tags:"
  jq -r '.tags[]? // empty' "$role_file" | while IFS= read -r tag; do
    echo "  - $tag"
  done
}
