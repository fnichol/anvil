#!/usr/bin/env sh
# shellcheck disable=SC3043

# shuck: source=../../argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"

print_usage_config() {
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

  usage() {
    print_usage_config "$program"
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
    edit)
      # shuck: source=edit.sh
      . "$SRC_ROOT/lib/anvil/commands/config/edit.sh"
      cmd_config_edit "$program" "$@"
      ;;
    init)
      # shuck: source=init.sh
      . "$SRC_ROOT/lib/anvil/commands/config/init.sh"
      cmd_config_init "$program" "$@"
      ;;
    show)
      # shuck: source=show.sh
      . "$SRC_ROOT/lib/anvil/commands/config/show.sh"
      cmd_config_show "$program" "$@"
      ;;
    *)
      usage_and_die "unknown subcommand: $subcommand"
      ;;
  esac
}
