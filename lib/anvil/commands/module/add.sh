#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/git.sh
. "$SRC_ROOT/lib/anvil/git.sh"

print_usage_module_add() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"
  local default_modules_lock_path="$4"

  cat <<-EOF
	Show details of a module

	USAGE:
	    $program module add [FLAGS] <URL>

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

  local name=""

  local branch=""
  local commit=""
  local tag=""
  local url

  OPTIND=1
  while getopts "b:c:hn:t:-:" arg; do
    case "$arg" in
      b)
        branch="$OPTARG"
        ;;
      c)
        commit="$OPTARG"
        ;;
      h)
        print_usage_module_add "$program" \
          "$default_config_path" "$default_data_home" \
          "$default_moduless_lock_path"
        return 0
        ;;
      n)
        name="$OPTARG"
        ;;
      t)
        tag="$OPTARG"
        ;;
      -)
        long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          branch=?*)
            branch="$long_optarg"
            ;;
          branch*)
            print_usage_module_add "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          commit=?*)
            commit="$long_optarg"
            ;;
          commit*)
            print_usage_module_add "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          help)
            print_usage_module_add "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path"
            return 0
            ;;
          name=?*)
            name="$long_optarg"
            ;;
          name*)
            print_usage_module_add "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          tag=?*)
            tag="$long_optarg"
            ;;
          tag*)
            print_usage_module_add "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_module_add "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_module_add "$program" \
          "$default_config_path" "$default_data_home" \
          "$default_moduless_lock_path" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  if [ -n "${1:-}" ]; then
    url="$1"
  else
    print_usage_module_add "$program" \
      "$default_config_path" "$default_data_home" \
      "$default_moduless_lock_path" >&2
    die "required argument: URL"
  fi

  if { [ -n "$branch" ] && [ -n "$commit" ]; } \
    || { [ -n "$branch" ] && [ -n "$tag" ]; } \
    || { [ -n "$commit" ] && [ -n "$tag" ]; }; then
    print_usage_module_add "$program" \
      "$default_config_path" "$default_data_home" \
      "$default_moduless_lock_path" >&2
    die "Options: branch, commit, and tag are mutually exclusive"
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

  ensure_jq

  info "Updating config"
  local tmp_config
  tmp_config="$(mktemp_file)"

  local config_jq_str
  config_jq_str='.modules += [{name: $name, url: $url}]'
  if [ -n "$branch" ]; then
    config_jq_str='.modules += [{name: $name, url: $url, branch: $branch}]'
  fi
  if [ -n "$commit" ]; then
    config_jq_str='.modules += [{name: $name, url: $url, commit: $commit}]'
  fi
  if [ -n "$tag" ]; then
    config_jq_str='.modules += [{name: $name, url: $url, tag: $tag}]'
  fi

  jq \
    --arg name "$name" \
    --arg url "$url" \
    --arg branch "$branch" \
    --arg commit "$commit" \
    --arg tag "$tag" \
    "$config_jq_str" \
    "$config_file" \
    >"$tmp_config"
  mv "$tmp_config" "$config_file"

  local current_sha
  current_sha="$(git_current_sha "$mod_path")"

  module_lock_update_for \
    "$config_file" \
    "$modules_lock_file" \
    "$name" \
    "$current_sha"
}
