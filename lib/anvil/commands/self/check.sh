#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/anvil.sh
. "$SRC_ROOT/lib/anvil/anvil.sh"

print_usage_self_check() {
  local program="$1"

  cat <<-EOF
	Checks if a newer version of Anvil is available

	USAGE:
	    $program self check [FLAGS]

	FLAGS:
	    -h, --help      Prints help information

	EXIT CODES:
	    0               Installed version is up to date
	    1               A newer version is available
	    2               Latest version could not be determined
	EOF
}

cmd_self_check() {
  local program version
  program="$1"
  shift
  version="$1"
  shift

  usage() {
    print_usage_self_check "$program"
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

  local latest
  latest="$(latest_anvil_version)"

  if [ -z "$latest" ]; then
    warn "Could not determine latest version of '$program'"
    exit 2
  fi

  if anvil_version_lt "$version" "$latest"; then
    info "$program $latest is available (installed: $version)"
    exit 1
  else
    info "$program $version is up to date"
    exit 0
  fi
}
