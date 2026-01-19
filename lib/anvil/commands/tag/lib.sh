#!/usr/bin/env sh
# shellcheck disable=SC3043

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
  local root program
  root="$1"
  shift
  program="$1"
  shift

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_tag "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_tag "$program"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_tag_usage "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_tag "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  local subcommand="${1:-}"
  if [ -z "$subcommand" ]; then
    print_usage_tag "$program"
    return 0
  fi
  shift

  case "$subcommand" in
    list)
      . "$root/lib/anvil/commands/tag/list.sh"
      cmd_tag_list "$root" "$program" "$@"
      ;;
    show)
      . "$root/lib/anvil/commands/tag/show.sh"
      cmd_tag_show "$root" "$program" "$@"
      ;;
    *)
      die "unknown tag subcommand: $subcommand"
      ;;
  esac
}
