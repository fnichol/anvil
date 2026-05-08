#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"

print_usage_config_init() {
  local program="$1"
  local default_config_path="$2"

  cat <<-EOF
	Initialize a config file
	
	USAGE:
	    $program config init [FLAGS] [OPTIONS]
	
	FLAGS:
	    -h, --help              Prints help information

	OPTIONS:
	    -f, --fqdn=<FQDN>       Host FQDN (bare hostname will append .local
	                            as FQDN)
	    -r, --role=<R>[,<R>..]  Roles to use in config
	    -t, --tag=<T>[,<T>..]   Tags to use in config

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	EOF
}

cmd_config_init() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"

  usage() {
    print_usage_config_init \
      "$program" \
      "$default_config_path"
  }

  local fqdn=""
  local roles=""
  local tags=""

  while [ $# -gt 0 ]; do
    case "$1" in
      # Flags
      -h | --help)
        usage
        return 0
        ;;
      # Options
      -f | --fqdn)
        ensure_required_arg "$1" "${2:-}"
        fqdn="$2"
        shift 2
        ;;
      -f=?* | --fqdn=?*)
        fqdn="${1#*=}"
        shift 1
        ;;
      -r | --role)
        ensure_required_arg "$1" "${2:-}"
        roles="${roles:+$roles,}$2" # roles are comma-delimited
        shift 2
        ;;
      -r=?* | --role=?*)
        roles="${roles:+$roles,}${1#*=}" # roles are comma-delimited
        shift 1
        ;;
      -t | --tag)
        ensure_required_arg "$1" "${2:-}"
        tags="${tags:+$tags,}$2" # tags are comma-delimited
        shift 2
        ;;
      -t=?* | --tag=?*)
        tags="${tags:+$tags,}${1#*=}" # tags are comma-delimited
        shift 1
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

  # Append `.local` to fqdn if no domain part is present
  case "$fqdn" in
    *.*)
      :
      ;;
    ?*)
      fqdn="$fqdn.local"
      ;;
  esac

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"

  config_create "$config_file" "$tags" "$roles" "$fqdn" \
    || die "Failed to init config"

  section "Created config file: $config_file"
}
