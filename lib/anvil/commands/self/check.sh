#!/usr/bin/env sh
# shellcheck disable=SC3043

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

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_self_check "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_self_check "$program"
            return 0
            ;;
          '')
            break
            ;;
          *)
            print_usage_self_check "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_self_check "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

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
