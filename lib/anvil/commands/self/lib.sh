#!/usr/bin/env sh
# shellcheck disable=SC3043

print_usage_self() {
  local program="$1"

  cat <<-EOF
	Manage the Anvil installation

	USAGE:
	    $program self [FLAGS] [COMMAND]

	FLAGS:
	    -h, --help      Prints help information

	COMMANDS:
	    check           Check if a newer version of Anvil is available
	    update          Update Anvil to the latest release
	EOF
}

cmd_self() {
  local program version
  program="$1"
  shift
  version="$1"
  shift

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_self "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_self "$program"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_self "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_self "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  local subcommand="${1:-}"
  if [ -z "$subcommand" ]; then
    print_usage_self "$program"
    return 0
  fi
  shift

  case "$subcommand" in
    check)
      . "$SRC_ROOT/lib/anvil/commands/self/check.sh"
      cmd_self_check "$program" "$version" "$@"
      ;;
    update)
      . "$SRC_ROOT/lib/anvil/commands/self/update.sh"
      cmd_self_update "$program" "$version" "$@"
      ;;
    *)
      print_usage_self "$program" >&2
      die "unknown subcommand: $subcommand"
      ;;
  esac
}
