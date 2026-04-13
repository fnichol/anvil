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
  local program
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
            print_config_usage "$program" >&2
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
      # shellcheck source=lib/anvil/commands/config/edit.sh
      . "$SRC_ROOT/lib/anvil/commands/config/edit.sh"
      cmd_config_edit "$program" "$@"
      ;;
    init)
      # shellcheck source=lib/anvil/commands/config/init.sh
      . "$SRC_ROOT/lib/anvil/commands/config/init.sh"
      cmd_config_init "$program" "$@"
      ;;
    show)
      # shellcheck source=lib/anvil/commands/config/show.sh
      . "$SRC_ROOT/lib/anvil/commands/config/show.sh"
      cmd_config_show "$program" "$@"
      ;;
    *)
      print_config_usage "$program" >&2
      die "unknown subcommand: $subcommand"
      ;;
  esac
}
