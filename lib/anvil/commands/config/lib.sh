#!/usr/bin/env sh
# shellcheck disable=SC3043

print_config_usage() {
  local program="$1"

  cat <<-EOF
	Manage configuration
	
	USAGE:
	    $program config [FLAGS] [COMMAND]
	
	FLAGS:
	    -h, --help      Prints help information
	
	COMMANDS:
	    edit            Edit current config
	    init            Initialize a config file
	    show            Show current config
	EOF
}

cmd_config() {
  local root program
  root="$1"
  shift
  program="$1"
  shift

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_config_usage "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_config_usage "$program"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_config_usage "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  local subcommand="${1:-}"
  if [ -z "$subcommand" ]; then
    print_config_usage "$program"
    return 0
  fi
  shift

  case "$subcommand" in
    edit)
      . "$root/lib/anvil/commands/config/edit.sh"
      cmd_config_edit "$root" "$program" "$@"
      ;;
    init)
      . "$root/lib/anvil/commands/config/init.sh"
      cmd_config_init "$root" "$program" "$@"
      ;;
    show)
      . "$root/lib/anvil/commands/config/show.sh"
      cmd_config_show "$root" "$program" "$@"
      ;;
    *)
      die "unknown config subcommand: $subcommand"
      ;;
  esac
}
