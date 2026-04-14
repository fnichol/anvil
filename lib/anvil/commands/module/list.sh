#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"

print_usage_module_list() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	List registered modules

	USAGE:
	    $program module list [FLAGS]

	FLAGS:
	    -h, --help              Prints help information

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

cmd_module_list() {
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
        print_usage_module_list "$program" \
          "$default_config_path" "$default_data_home"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_module_list "$program" \
              "$default_config_path" "$default_data_home"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_module_list "$program" \
              "$default_config_path" "$default_data_home" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_module_list "$program" \
          "$default_config_path" "$default_data_home" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"

  if ! config_exists "$config_file"; then
    warn "No configuration found. Run 'anvil config init' first."
    return 0
  fi

  ensure_jq

  local module_count
  module_count="$(jq '.modules | length' "$config_file")"

  if [ "$module_count" -eq 0 ]; then
    warn "No modules registered. Run 'anvil module add <url>' to add one."
    return 0
  fi

  printf "%-30s %-50s %-10s %s\n" "NAME" "URL" "CONSTRAINT" "STATUS"
  printf "%-30s %-50s %-10s %s\n" "----" "---" "----------" "------"

  jq -r '
    .modules[]
      | [.name, .url, (.branch // .tag // .commit // "(default)")]
      | @tsv
  ' "$config_file" \
    | while IFS="$(printf '\t')" read -r name url constraint; do
      local status

      if module_is_installed "$data_home" "$name"; then
        status="installed"
      else
        status="not installed"
      fi

      printf "%-30s %-50s %-10s %s\n" "$name" "$url" "$constraint" "$status"
    done
}
