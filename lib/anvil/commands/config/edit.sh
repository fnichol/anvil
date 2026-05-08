#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"

print_usage_config_edit() {
  local program="$1"
  local default_config_path="$2"

  cat <<-EOF
	Edit current config
	
	USAGE:
	    $program config edit [FLAGS]
	
	FLAGS:
	    -h, --help              Prints help information

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	EOF
}

cmd_config_edit() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"

  usage() {
    print_usage_config_edit "$program" "$default_config_path"
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

  if ! config_exists "$config_file"; then
    warn "Existing config not detected: $config_file"
    warn "Hint: try the '$program config init' subcommand to init a config"
    die "Config file does not exist"
  fi

  local editor="${VISUAL:-${EDITOR:-vi}}"

  need_cmd "$editor"

  "$editor" "$config_file"
}
