#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/git.sh
. "$SRC_ROOT/lib/anvil/git.sh"

print_usage_module_check() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"
  local default_modules_lock_path="$4"

  cat <<-EOF
	Checks if modules lock file is out of date

	USAGE:
	    $program module check [FLAGS] [--] [<NAME> ..]

	FLAGS:
	    -h, --help              Prints help information
	    -i, --installed         Additionally checks the installed status

	ARGS:
	    <NAME>                  Module name alias

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	    ANVIL_MODULES_LOCK_PATH [default: $default_modules_lock_path]
	EOF
}

cmd_module_check() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"
  local default_moduless_lock_path modules_lock_file
  default_moduless_lock_path="$(modules_lock_path)"

  local installed=""
  local modules

  OPTIND=1
  while getopts "hi-:" arg; do
    case "$arg" in
      h)
        print_usage_module_check "$program" \
          "$default_config_path" "$default_data_home" \
          "$default_moduless_lock_path"
        return 0
        ;;
      i)
        installed="true"
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_module_check "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path"
            return 0
            ;;
          installed)
            installed="true"
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_module_check "$program" \
              "$default_config_path" "$default_data_home" \
              "$default_moduless_lock_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_module_check "$program" \
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

  section "Checking modules"

  local ec
  ec="$(mktemp_file)"
  cleanup_file "$ec"
  echo 0 >"$ec"

  echo "$modules" | while read -r name; do
    local status
    if ! status="$(
      module_lock_status_for "$config_file" "$modules_lock_file" "$name"
    )"; then
      die "error when determining status of '$name'"
    fi

    if [ -n "$installed" ]; then
      if ! module_is_installed "$data_home" "$name"; then
        case "$status" in
          pin-current)
            info "$(module_message "$name" "Current (pinned, not installed)")"
            echo 1 >"$ec"
            continue
            ;;
          lock-current)
            info "$(module_message "$name" "Current (not installed)")"
            echo 1 >"$ec"
            continue
            ;;
          pin-outdated)
            info "$(module_message "$name" "Outdated (pinned, not installed)")"
            echo 1 >"$ec"
            continue
            ;;
          lock-outdated)
            info "$(module_message "$name" "Outdated (not installed)")"
            echo 1 >"$ec"
            continue
            ;;
          *)
            die "invalid status for '$name': $status"
            ;;
        esac
      fi

      if ! module_is_current_with_lock_for \
        "$data_home" "$modules_lock_file" "$name"; then
        case "$status" in
          pin-current)
            info "$(module_message "$name" \
              "Current (pinned, checkout outdated)")"
            echo 1 >"$ec"
            continue
            ;;
          lock-current)
            info "$(module_message "$name" "Current (checkout outdated)")"
            echo 1 >"$ec"
            continue
            ;;
          pin-outdated)
            info "$(module_message "$name" \
              "Outdated (pinned, checkout outdated)")"
            echo 1 >"$ec"
            continue
            ;;
          lock-outdated)
            info "$(module_message "$name" "Outdated (checkout outdated)")"
            echo 1 >"$ec"
            continue
            ;;
          *)
            die "invalid status for '$name': $status"
            ;;
        esac
      fi
    fi

    case "$status" in
      pin-current)
        info "$(module_message "$name" "Current (pinned)")"
        continue
        ;;
      lock-current)
        info "$(module_message "$name" "Current")"
        continue
        ;;
      pin-outdated)
        info "$(module_message "$name" "Outdated (pinned)")"
        echo 1 >"$ec"
        continue
        ;;
      lock-outdated)
        info "$(module_message "$name" "Outdated")"
        echo 1 >"$ec"
        continue
        ;;
      *)
        die "invalid status for '$name': $status"
        ;;
    esac
  done

  echo ""
  if [ "$(cat "$ec")" = "0" ]; then
    info "All modules are current"
  elif [ -n "$installed" ]; then
    warn "Some modules are outdated, not installed, or checkout outdated"
    exit 1
  else
    warn "Some modules are outdated"
    exit 1
  fi
}
