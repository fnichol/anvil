#!/usr/bin/env sh
# shellcheck disable=SC3043

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

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_module "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_module "$program"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_module "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_module "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  local subcommand="${1:-}"
  if [ -z "$subcommand" ]; then
    print_usage_module "$program"
    return 0
  fi
  shift

  case "$subcommand" in
    add)
      . "$root/lib/anvil/commands/module/add.sh"
      cmd_module_add "$program" "$@"
      ;;
    check)
      . "$root/lib/anvil/commands/module/check.sh"
      cmd_module_check "$program" "$@"
      ;;
    install)
      . "$root/lib/anvil/commands/module/install.sh"
      cmd_module_install "$program" "$@"
      ;;
    list)
      . "$root/lib/anvil/commands/module/list.sh"
      cmd_module_list "$program" "$@"
      ;;
    remove)
      . "$root/lib/anvil/commands/module/remove.sh"
      cmd_module_remove "$program" "$@"
      ;;
    show)
      . "$root/lib/anvil/commands/module/show.sh"
      cmd_module_show "$program" "$@"
      ;;
    update)
      . "$root/lib/anvil/commands/module/update.sh"
      cmd_module_update "$program" "$@"
      ;;
    *)
      print_usage_module "$program" >&2
      die "unknown subcommand: $subcommand"
      ;;
  esac
}
