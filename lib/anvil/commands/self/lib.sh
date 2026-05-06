#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"

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

  usage() {
    print_usage_self "$program"
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
    check)
      . "$SRC_ROOT/lib/anvil/commands/self/check.sh"
      cmd_self_check "$program" "$version" "$@"
      ;;
    update)
      . "$SRC_ROOT/lib/anvil/commands/self/update.sh"
      cmd_self_update "$program" "$version" "$@"
      ;;
    *)
      usage_and_die "unknown subcommand: $subcommand"
      ;;
  esac
}
