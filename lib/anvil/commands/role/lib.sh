#!/usr/bin/env sh
# shellcheck disable=SC3043

print_usage_role() {
  local program="$1"

  cat <<-EOF
	Manage roles
	
	USAGE:
	    $program role [FLAGS] [COMMAND]
	
	FLAGS:
	    -h, --help      Prints help information
	
	COMMANDS:
	    list            List available roles
	    show            Show details of a role
	EOF
}

cmd_role() {
  local root program
  root="$1"
  shift
  program="$1"
  shift

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_role "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_role "$program"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_role_usage "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_role "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  local subcommand="${1:-}"
  if [ -z "$subcommand" ]; then
    print_usage_role "$program"
    return 0
  fi
  shift

  case "$subcommand" in
    list)
      . "$root/lib/anvil/commands/role/list.sh"
      cmd_role_list "$root" "$program" "$@"
      ;;
    show)
      . "$root/lib/anvil/commands/role/show.sh"
      cmd_role_show "$root" "$program" "$@"
      ;;
    *)
      die "unknown role subcommand: $subcommand"
      ;;
  esac
}
