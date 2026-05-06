#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/facts.sh
. "$SRC_ROOT/lib/anvil/facts.sh"

print_usage_facts() {
  local program="$1"

  cat <<-EOF
	Show discovered system info
	
	USAGE:
	    $program facts [FLAGS]
	
	FLAGS:
	    -h, --help              Prints help information
	EOF
}

cmd_facts() {
  local program
  program="$1"
  shift

  usage() {
    print_usage_facts "$program"
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

  facts_json
}
