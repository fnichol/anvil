#!/usr/bin/env sh
# shellcheck disable=SC3043

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
  local root program
  root="$1"
  shift
  program="$1"
  shift

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_facts "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_facts "$program"
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
        print_usage_facts "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  . "$root/lib/anvil/jq.sh"
  . "$root/lib/anvil/facts.sh"

  facts_json
}
