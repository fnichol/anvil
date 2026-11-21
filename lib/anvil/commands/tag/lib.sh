#!/usr/bin/env sh
# shellcheck disable=SC3043
#
# shuck: source=../../argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"

print_usage_tag() {
  local program="$1"

  cat <<-EOF
	Manage tags
	
	USAGE:
	    $program tag [FLAGS] [COMMAND]
	
	FLAGS:
	    -h, --help      Prints help information
	
	COMMANDS:
	    list            List available tags
	    show            Show details of a tag
	EOF
}

cmd_tag() {
  local program
  program="$1"
  shift

  usage() {
    print_usage_tag "$program"
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
      # shuck: source=list.sh
      . "$SRC_ROOT/lib/anvil/commands/tag/list.sh"
      cmd_tag_list "$program" "$@"
      ;;
    show)
      # shuck: source=show.sh
      . "$SRC_ROOT/lib/anvil/commands/tag/show.sh"
      cmd_tag_show "$program" "$@"
      ;;
    *)
      usage_and_die "unknown subcommand: $subcommand"
      ;;
  esac
}
