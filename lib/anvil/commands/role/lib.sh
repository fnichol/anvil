#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"

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
  local program
  program="$1"
  shift

  usage() {
    print_usage_role "$program"
  }

  while [ $# -gt 0 ]; do
    case "$1" in
      # Flags
      -h | --help)
        usage
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
    list)
      # shellcheck source=lib/anvil/commands/role/list.sh
      . "$SRC_ROOT/lib/anvil/commands/role/list.sh"
      cmd_role_list "$program" "$@"
      ;;
    show)
      # shellcheck source=lib/anvil/commands/role/show.sh
      . "$SRC_ROOT/lib/anvil/commands/role/show.sh"
      cmd_role_show "$program" "$@"
      ;;
    *)
      usage_and_die "unknown subcommand: $subcommand"
      ;;
  esac
}
