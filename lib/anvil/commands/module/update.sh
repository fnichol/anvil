#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/git.sh
. "$SRC_ROOT/lib/anvil/git.sh"

print_usage_module_update() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"
  local default_modules_lock_path="$4"

  cat <<-EOF
	Updates modules if any are out of date

	USAGE:
	    $program module update [FLAGS] [--] [<NAME> ..]

	FLAGS:
	    -h, --help              Prints help information

	ARGS:
	    <NAME>                  Module name alias

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	    ANVIL_MODULES_LOCK_PATH [default: $default_modules_lock_path]
	EOF
}

cmd_module_update() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"
  local default_moduless_lock_path modules_lock_file
  default_moduless_lock_path="$(modules_lock_path)"

  local modules

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_module_update "$program" \
          "$default_config_path" "$default_data_home" \
          "$default_moduless_lock_path"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_module_update "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_module_update "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_module_update "$program" \
          "$default_config_path" "$default_data_home" \
          "$default_moduless_lock_path" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"
  modules_lock_file="${ANVIL_MODULES_LOCK_PATH:-$default_moduless_lock_path}"

  if ! config_exists "$config_file"; then
    warn "No config found at: $config_file"
    warn "Run: $program config init"
    die "Config file not found"
  fi

  if [ -n "$*" ]; then
    modules="$(echo "$*" | tr ' ' '\n')"
  else
    modules="$(modules_registered_names "$config_file")"
  fi

  section "Updating modules"

  echo "$modules" | while read -r name; do
    ensure_jq

    local config_json
    config_json="$(module_config_json_for "$config_file" "$name")"

    if [ -z "$config_json" ]; then
      die "Missing configuration for module named '$name'"
    fi

    local mod_path
    mod_path="$(module_path_for "$data_home" "$name")"

    if ! module_is_installed "$data_home" "$name"; then
      # Install from scratch if not installed

      local url commit
      url="$(echo "$config_json" | jq -r '.url // empty')"
      commit="$(
        echo "$config_json" | jq -r '.branch // .tag // .commit // empty'
      )"

      if [ -z "$url" ]; then
        die "Missing configuration URL for module named '$name'"
      fi

      module_install "$mod_path" "$url" "$commit"
    else
      # Otherwise Git pull update

      local ref
      ref="$(
        echo "$config_json" | jq -r '.branch // .tag // .commit // "HEAD"'
      )"

      module_pull_update "$mod_path" "$ref"
    fi

    local current_sha
    current_sha="$(git_current_sha "$mod_path")"

    if module_is_current_with_lock_for \
      "$data_home" "$modules_lock_file" "$name"; then
      info "$(module_message "$name" "Lock file current; skipping update")"
    else
      # Only update lock file if lock file needs an update
      module_lock_update_for \
        "$config_file" \
        "$modules_lock_file" \
        "$name" \
        "$current_sha"
    fi
  done
}
