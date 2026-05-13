#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"

print_usage_config_init() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"
  local default_modules_lock_path="$4"

  cat <<-EOF
	Initialize a config file
	
	USAGE:
	    $program config init [FLAGS] [OPTIONS]
	
	FLAGS:
	    -a, --apply               Run apply after initializing
	    -h, --help                Prints help information
	    -i, --install             Install added modules

	OPTIONS:
	    -f, --fqdn=<FQDN>         Host FQDN (bare hostname will append
	                              .local as FQDN)
	    -m, --module=<M>[,<M>..]  Modules to add in config
	    -r, --role=<R>[,<R>..]    Roles to use in config
	    -t, --tag=<T>[,<T>..]     Tags to use in config

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH         [default: $default_config_path]
	    ANVIL_DATA_HOME           [default: $default_data_home]
	    ANVIL_MODULES_LOCK_PATH   [default: $default_modules_lock_path]
	EOF
}

cmd_config_init() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"
  local default_moduless_lock_path modules_lock_file
  default_moduless_lock_path="$(modules_lock_path)"

  usage() {
    print_usage_config_init \
      "$program" \
      "$default_config_path" \
      "$default_data_home" \
      "$default_moduless_lock_path"
  }

  local apply=""
  local install=""
  local fqdn=""
  local modules=""
  local roles=""
  local tags=""

  while [ $# -gt 0 ]; do
    case "$1" in
      # Flags
      -a | --apply)
        apply="true"
        shift 1
        ;;
      -h | --help)
        usage
        return 0
        ;;
      -i | --install)
        install="true"
        shift 1
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
      -m | --module)
        ensure_required_arg "$1" "${2:-}"
        modules="${modules:+$modules,}$2" # modules are comma-delimited
        shift 2
        ;;
      -m=?* | --module=?*)
        modules="${modules:+$modules,}${1#*=}" # modules are comma-delimited
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
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"
  modules_lock_file="${ANVIL_MODULES_LOCK_PATH:-$default_moduless_lock_path}"

  config_create "$config_file" "$tags" "$roles" "$fqdn" \
    || die "Failed to init config"

  section "Created config file: $config_file"

  local module
  echo "$modules" | tr ',' ' ' | while read -r module; do
    if [ -z "$module" ]; then
      continue
    fi

    local name url
    if echo "$module" | grep -q '::'; then
      url="$(echo "$module" | awk -F '::' '{print $2}')"
      # Normalize URL
      url="$(module_expand_url "$url")"
      name="$(echo "$module" | awk -F '::' '{print $1}')"
    else
      url="$module"
      # Normalize URL
      url="$(module_expand_url "$url")"
      name="$(module_name_from_url "$url")"
    fi

    local mod_path
    mod_path="$(module_path_for "$data_home" "$name")"

    if [ -d "$mod_path" ]; then
      die "Module directory $mod_path already exists; fix or delete & try again"
    fi

    section "Adding module $name"

    module_config_add \
      "$config_file" \
      "$name" \
      "$url" \
      "" \
      "" \
      ""

    if [ -n "$install" ]; then
      module_install "$mod_path" "$url"

      local current_sha
      current_sha="$(git_current_sha "$mod_path")"

      module_lock_update_for \
        "$config_file" \
        "$modules_lock_file" \
        "$name" \
        "$current_sha"
    fi
  done

  if [ -n "$apply" ]; then
    # Trigger trap cleanups before exec'ing
    trap_cleanups

    ANVIL_CONFIG_PATH="$config_file" \
      ANVIL_DATA_HOME="$data_home" \
      ANVIL_MODULES_LOCK_PATH="$modules_lock_file" \
      exec "$0" apply
  fi
}
