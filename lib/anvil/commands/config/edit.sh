#!/usr/bin/env sh
# shellcheck disable=SC3043

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
  local root program
  root="$1"
  shift
  program="$1"
  shift

  . "$root/lib/anvil/config.sh"

  local default_config_path config_file

  default_config_path="$(config_path)"

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_config_edit "$program" "$default_config_path"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_config_edit "$program" "$default_config_path"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage "$program" "$default_config_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_config_edit "$program" "$default_config_path" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

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
