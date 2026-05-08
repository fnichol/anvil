#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/git.sh
. "$SRC_ROOT/lib/anvil/git.sh"

print_usage_module_add() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"
  local default_modules_lock_path="$4"

  cat <<-EOF
	Add a module

	USAGE:
	    $program module add [FLAGS] [OPTIONS] <URL>

	FLAGS:
	    -h, --help              Prints help information

	OPTIONS:
	    -b, --branch=<BRANCH>   Tracking Git branch
	    -c, --commit=<COMMIT>   Pin module to Git commit SHA
	    -n, --name=<NAME>       Optonal module name alias
	    -t, --tag=<TAG>         Pin module to Git tag

	ARGUMENTS:
	    <URL>                   Git clone URL

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	    ANVIL_MODULES_LOCK_PATH [default: $default_modules_lock_path]
	EOF
}

cmd_module_add() {
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
    print_usage_module_add \
      "$program" \
      "$default_config_path" \
      "$default_data_home" \
      "$default_moduless_lock_path"
  }

  local name=""

  local branch=""
  local commit=""
  local tag=""
  local url

  while [ $# -gt 0 ]; do
    case "$1" in
      # Flags
      -h | --help)
        usage
        return 0
        ;;
      # Options
      -b | --branch)
        ensure_required_arg "$1" "${2:-}"
        branch="$2"
        shift 2
        ;;
      -b=?* | --branch=?*)
        branch="${1#*=}"
        shift 1
        ;;
      -c | --commit)
        ensure_required_arg "$1" "${2:-}"
        commit="$2"
        shift 2
        ;;
      -c=?* | --commit=?*)
        commit="${1#*=}"
        shift 1
        ;;
      -n | --name)
        ensure_required_arg "$1" "${2:-}"
        name="$2"
        shift 2
        ;;
      -n=?* | --name=?*)
        name="${1#*=}"
        shift 1
        ;;
      -t | --tag)
        ensure_required_arg "$1" "${2:-}"
        tag="$2"
        shift 2
        ;;
      -t=?* | --tag=?*)
        tag="${1#*=}"
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

  if [ -n "${1:-}" ]; then
    url="$1"
  else
    usage_and_die "required argument: URL"
  fi

  if { [ -n "$branch" ] && [ -n "$commit" ]; } \
    || { [ -n "$branch" ] && [ -n "$tag" ]; } \
    || { [ -n "$commit" ] && [ -n "$tag" ]; }; then
    usage_and_die "Options: branch, commit, and tag are mutually exclusive"
  fi

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"
  modules_lock_file="${ANVIL_MODULES_LOCK_PATH:-$default_moduless_lock_path}"

  if ! config_exists "$config_file"; then
    warn "No config found at: $config_file"
    warn "Run: $program config init"
    die "Config file not found"
  fi

  # Normalize URL
  url="$(module_expand_url "$url")"

  # Derive a module name alias if not given
  if [ -z "$name" ]; then
    name="$(module_name_from_url "$url")"
  fi

  # Confirm named module is not already registered
  if modules_installed_names "$config_file" "$data_home" \
    | grep -q "^$name$"; then
    die "Module named '$name' already present. Run 'anvil module list'"
  fi

  local mod_path
  mod_path="$(module_path_for "$data_home" "$name")"

  if [ -d "$mod_path" ]; then
    die "Module directory $mod_path already exists; fix or delete and try again"
  fi

  section "Adding module $name"

  if [ -n "$branch" ]; then
    module_install "$mod_path" "$url" "$branch"
  elif [ -n "$commit" ]; then
    module_install "$mod_path" "$url" "$commit"
  elif [ -n "$tag" ]; then
    module_install "$mod_path" "$url" "$tag"
  else
    module_install "$mod_path" "$url"
  fi

  module_config_add \
    "$config_file" \
    "$name" \
    "$url" \
    "$branch" \
    "$commit" \
    "$tag"

  local current_sha
  current_sha="$(git_current_sha "$mod_path")"

  module_lock_update_for \
    "$config_file" \
    "$modules_lock_file" \
    "$name" \
    "$current_sha"
}
