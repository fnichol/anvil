#!/usr/bin/env sh
# shellcheck disable=SC3043

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
	    role            Manage roles
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

  VERBOSE=""

  OPTIND=1
  while getopts "hvV-:" arg; do
    case "$arg" in
      h)
        print_usage "$program" "$version" "$author"
        return 0
        ;;
      v)
        VERBOSE=true
        ;;
      V)
        print_version "$program" "$version" "${VERBOSE:-}"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage "$program" "$version" "$author"
            return 0
            ;;
          verbose)
            VERBOSE=true
            ;;
          version)
            print_version "$program" "$version" "${VERBOSE:-}"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage "$program" "$version" "$author" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage "$program" "$version" "$author" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  local command="${1:-}"
  if [ -z "$command" ]; then
    print_usage "$program" "$version" "$author"
    return 0
  fi
  shift

  case "$command" in
    apply)
      . "$root/lib/anvil/commands/apply.sh"
      cmd_apply "$root" "$program" "$@"
      ;;
    config)
      . "$root/lib/anvil/commands/config/lib.sh"
      cmd_config "$root" "$program" "$@"
      ;;
    diff)
      . "$root/lib/anvil/commands/diff.sh"
      cmd_diff "$root" "$program" "$@"
      ;;
    doctor)
      . "$root/lib/anvil/commands/doctor.sh"
      cmd_doctor "$root" "$program" "$@"
      ;;
    facts)
      . "$root/lib/anvil/commands/facts.sh"
      cmd_facts "$root" "$program" "$@"
      ;;
    role)
      . "$root/lib/anvil/commands/role/lib.sh"
      cmd_role "$root" "$program" "$@"
      ;;
    tag)
      . "$root/lib/anvil/commands/tag/lib.sh"
      cmd_tag "$root" "$program" "$@"
      ;;
    status)
      . "$root/lib/anvil/commands/status.sh"
      cmd_status "$root" "$program" "$@"
      ;;
    *)
      print_usage "$program" "$version" "$author" >&2
      die "unknown command: $command"
      ;;
  esac
}
