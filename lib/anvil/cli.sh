#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"

# Anvil CLI command parsing

print_usage() {
  local program="$1"
  local version="$2"
  local author="$3"

  cat <<-EOF
	$program $version

	System provisioning and configuration management
	
	USAGE:
	    $program [FLAGS] [COMMAND]
	
	FLAGS:
	    -h, --help      Prints help information
	    -V, --version   Prints version information
	    -v, --verbose   Prints verbose output
	
	COMMANDS:
	    apply           Converge system to desired state
	    config          Manage configuration
	    diff            Show what would change
	    doctor          Verify system health
	    facts           Show discovered system info
	    module          Manage modules
	    role            Manage roles
	    self            Manage the Anvil installation
	    tag             Manage tags
	    status          Show current vs desired state
	EOF
}

anvil_cli() {
  local root program version author
  root="$1"
  shift
  program="$1"
  shift
  version="$1"
  shift
  author="$1"
  shift

  usage() {
    print_usage "$program" "$version" "$author"
  }

  VERBOSE=""

  while [ $# -gt 0 ]; do
    case "$1" in
      # Flags
      -h | --help)
        usage
        return 0
        ;;
      -v | --verbose)
        VERBOSE=true
        shift 1
        ;;
      -V | --version)
        print_version "$program" "$version" "${VERBOSE:-}"
        return 0
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

  local subcommand="${1:-}"
  if [ -z "$subcommand" ]; then
    usage
    return 0
  fi
  shift

  case "$subcommand" in
    apply)
      . "$root/lib/anvil/commands/apply.sh"
      cmd_apply "$program" "$version" "$@"
      ;;
    config)
      . "$root/lib/anvil/commands/config/lib.sh"
      cmd_config "$program" "$@"
      ;;
    diff)
      . "$root/lib/anvil/commands/diff.sh"
      cmd_diff "$program" "$@"
      ;;
    doctor)
      . "$root/lib/anvil/commands/doctor.sh"
      cmd_doctor "$program" "$@"
      ;;
    facts)
      . "$root/lib/anvil/commands/facts.sh"
      cmd_facts "$program" "$@"
      ;;
    module)
      . "$root/lib/anvil/commands/module/lib.sh"
      cmd_module "$program" "$@"
      ;;
    role)
      . "$root/lib/anvil/commands/role/lib.sh"
      cmd_role "$program" "$@"
      ;;
    self)
      . "$root/lib/anvil/commands/self/lib.sh"
      cmd_self "$program" "$version" "$@"
      ;;
    tag)
      . "$root/lib/anvil/commands/tag/lib.sh"
      cmd_tag "$program" "$@"
      ;;
    status)
      . "$root/lib/anvil/commands/status.sh"
      cmd_status "$program" "$@"
      ;;
    *)
      usage_and_die "unknown subcommand: $subcommand"
      ;;
  esac
}
