#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/script.sh
. "$SRC_ROOT/lib/anvil/script.sh"
# shellcheck source=lib/anvil/logging.sh
. "$SRC_ROOT/lib/anvil/logging.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/phases.sh
. "$SRC_ROOT/lib/anvil/phases.sh"
# shellcheck source=lib/anvil/state.sh
. "$SRC_ROOT/lib/anvil/state.sh"
# shellcheck source=lib/anvil/anvil.sh
. "$SRC_ROOT/lib/anvil/anvil.sh"

# Prints usage for the apply command.
print_apply_usage() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	Converge system to desired state

	USAGE:
	    $program apply [FLAGS]

	FLAGS:
	    -h, --help                  Prints help information
	    -n, --dry-run               Show what would change without applying
	        --skip=<p:s>[,<p:s>..]  Skip steps (supports:
                                        phase:*, *:step, *:*)

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

# Apply command - converge system to desired state
cmd_apply() {
  local program version
  program="$1"
  shift
  version="$1"
  shift

  ensure_script

  logging_exec "anvil-apply" "$0" apply "$@"

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"

  local dry_run=""
  local cli_skip_steps=""

  OPTIND=1
  while getopts "hn-:" arg; do
    case "$arg" in
      h)
        print_apply_usage "$program" \
          "$default_config_path" "$default_data_home"
        return 0
        ;;
      n)
        dry_run=true
        ;;
      -)
        long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_apply_usage "$program" \
              "$default_config_path" "$default_data_home"
            return 0
            ;;
          dry-run)
            dry_run=true
            ;;
          skip=?*)
            cli_skip_steps="$long_optarg"
            ;;
          skip*)
            print_apply_usage "$program" \
              "$default_config_path" "$default_data_home" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_apply_usage "$program" \
              "$default_config_path" "$default_data_home" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_apply_usage "$program" \
          "$default_config_path" "$default_data_home" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  local start_time
  start_time="$(date +%s)"

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"

  if ! config_exists "$config_file"; then
    warn "No config found at: $config_file"
    warn "Run: $program config init"
    die "Config file not found"
  fi

  # Convert CLI-provided skip steps to be space-delimited
  cli_skip_steps="$(echo "$cli_skip_steps" | tr ',' ' ')"

  # Build skip coordinates by merging config skip_steps (newline-delimited)
  # with CLI provided values (space-delimited)
  local config_skip_steps
  config_skip_steps="$(config_read_skip_steps "$config_file")"
  local skip_coords
  skip_coords="$(
    printf '%s\n%s' "$config_skip_steps" "$cli_skip_steps" | tr '\n' ' '
  )"

  # If running in dry run mode, skip all apply phases, but still gather facts
  # and show diff
  if [ -n "$dry_run" ]; then
    skip_coords="$skip_coords prepare:acquire_sudo bootstrap:* update:* install:* configure:* finalize:*"
    warn "Dry-run mode: no changes will be applied"
  fi

  # Require at least one module to be installed
  if [ -z "$(modules_installed_names "$config_file" "$data_home")" ]; then
    warn "No modules are installed."
    warn ""
    warn "Run 'anvil module add <url>' to add a module,"
    warn "then 'anvil module install' to install it locally."

    die "Nothing configured to apply"
  fi

  section "Anvil Apply"

  phases_run "$config_file" "$data_home" "$skip_coords"

  echo
  section "Apply Complete"

  local elapsed_s
  elapsed_s="$(($(date +%s) - start_time))"
  info "Run time: $(
    printf '%02d:%02d (mm:ss)' "$((elapsed_s / 60))" "$((elapsed_s % 60))"
  )"

  check_anvil_update_advisory "$program" "$version"
}

check_anvil_update_advisory() {
  local program version
  program="$1"
  version="$2"

  local latest=""

  # Use cached result if still fresh
  if ! state_is_update_check_due; then
    latest="$(state_read_latest_known_version)"
  fi

  # Perform live check when cache is stale
  if [ -z "$latest" ]; then
    latest="$(latest_anvil_version)"

    # Write to cache regardless (even if empty, to avoid hammering the API)
    if [ -n "$latest" ]; then
      state_write_update_check "$latest" || true
    fi
  fi

  # Print advisory if newer version exists
  if [ -n "$latest" ] && anvil_version_lt "$version" "$latest"; then
    echo ""
    section "New $program version detected"
    info "$program $latest is available (installed: $version)."
    info "Run '$program self update' to upgrade."
  fi
}
