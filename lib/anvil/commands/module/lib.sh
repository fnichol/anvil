#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"

print_usage_module() {
  local program="$1"

  cat <<-EOF
	Manage Anvil modules

	USAGE:
	    $program module [FLAGS] [COMMAND]

	FLAGS:
	    -h, --help      Prints help information

	COMMANDS:
	    add             Register and fetch a module
	    check           Check if modules are up to date
	    install         Fetch registered modules not yet on disk
	    list            List registered modules
	    remove          Deregister and delete a module
	    show            Show details of a module
	    update          Pull latest for one or all modules
	EOF
}

cmd_module() {
  local program
  program="$1"
  shift

  usage() {
    print_usage_module "$program"
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
    add)
      . "$SRC_ROOT/lib/anvil/commands/module/add.sh"
      cmd_module_add "$program" "$@"
      ;;
    check)
      . "$SRC_ROOT/lib/anvil/commands/module/check.sh"
      cmd_module_check "$program" "$@"
      ;;
    install)
      . "$SRC_ROOT/lib/anvil/commands/module/install.sh"
      cmd_module_install "$program" "$@"
      ;;
    list)
      . "$SRC_ROOT/lib/anvil/commands/module/list.sh"
      cmd_module_list "$program" "$@"
      ;;
    remove)
      . "$SRC_ROOT/lib/anvil/commands/module/remove.sh"
      cmd_module_remove "$program" "$@"
      ;;
    show)
      . "$SRC_ROOT/lib/anvil/commands/module/show.sh"
      cmd_module_show "$program" "$@"
      ;;
    update)
      . "$SRC_ROOT/lib/anvil/commands/module/update.sh"
      cmd_module_update "$program" "$@"
      ;;
    *)
      usage_and_die "unknown subcommand: $subcommand"
      ;;
  esac
}
