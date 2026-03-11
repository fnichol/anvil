#!/usr/bin/env sh
# shellcheck disable=SC3043

# Prints usage for the apply command.
print_apply_usage() {
  local program="$1"
  local default_config_path="$2"

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
	EOF
}

# Apply command - converge system to desired state
cmd_apply() {
  local root program
  root="$1"
  shift
  program="$1"
  shift

  # shellcheck source=lib/anvil/logging.sh
  . "$root/lib/anvil/logging.sh"
  logging_exec "anvil-apply" "$0" apply "$@"

  . "$root/lib/anvil/jq.sh"
  . "$root/lib/anvil/config.sh"
  . "$root/lib/anvil/phases.sh"

  local default_config_path
  default_config_path="$(config_path)"

  local default_config_path config_file

  local dry_run=""
  local cli_skip_steps=""

  OPTIND=1
  while getopts "hn-:" arg; do
    case "$arg" in
      h)
        print_apply_usage "$program" "$default_config_path"
        return 0
        ;;
      n)
        dry_run=true
        ;;
      -)
        long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_apply_usage "$program" "$default_config_path"
            return 0
            ;;
          dry-run)
            dry_run=true
            ;;
          skip=?*)
            cli_skip_steps="$long_optarg"
            ;;
          skip*)
            print_apply_usage "$program" "$default_config_path" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_apply_usage "$program" "$default_config_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_apply_usage "$program" "$default_config_path" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"

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
    skip_coords="$skip_coords bootstrap:* update:* install:* configure:* finalize:*"
    warn "Dry-run mode: no changes will be applied"
  fi

  section "Anvil Apply"

  phases_run "$root" "$config_file" "$skip_coords"

  echo
  section "Apply Complete"
}
