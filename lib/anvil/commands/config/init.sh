#!/usr/bin/env sh
# shellcheck disable=SC3043

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
	    -r, --roles=<R>[,<R>..] Roles to use in config
	    -t, --tags=<T>[,<T>..]  Tags to use in config

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	EOF
}

cmd_config_init() {
  local program
  program="$1"
  shift

  local roles=""
  local tags=""
  local fqdn=""

  local default_config_path config_file
  default_config_path="$(config_path)"

  OPTIND=1
  while getopts "hf:r:t:-:" arg; do
    case "$arg" in
      h)
        print_usage_config_init "$program" \
          "$default_config_path"
        return 0
        ;;
      f)
        fqdn="$OPTARG"
        ;;
      r)
        roles="$OPTARG"
        ;;
      t)
        tags="$OPTARG"
        ;;
      -)
        long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_config_init "$program" \
              "$default_config_path"
            return 0
            ;;
          fqdn=?*)
            fqdn="$long_optarg"
            ;;
          fqdn*)
            print_usage_config_init "$program" \
              "$default_config_path" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          roles=?*)
            roles="$long_optarg"
            ;;
          roles*)
            print_usage_config_init "$program" \
              "$default_config_path" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          tags=?*)
            tags="$long_optarg"
            ;;
          tags*)
            print_usage_config_init "$program" \
              "$default_config_path" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage "$program" \
              "$default_config_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_config_init "$program" \
          "$default_config_path" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

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
