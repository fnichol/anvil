#!/usr/bin/env sh
# shellcheck disable=SC3043

print_usage_role_show() {
  local program="$1"

  cat <<-EOF
	Show details of a role
	
	USAGE:
	    $program role show [FLAGS] <NAME>
	
	FLAGS:
	    -h, --help              Prints help information

	ARGUMENTS:
	    <NAME>                  Name of the role
	EOF
}

cmd_role_show() {
  local root program
  root="$1"
  shift
  program="$1"
  shift

  . "$root/lib/anvil/jq.sh"

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_role_show "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_role_show "$program"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_role_show "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_role_show "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  if [ -n "${1:-}" ]; then
    name="$1"
  else
    print_usage_role_show "$program" >&2
    die "required argument: NAME"
  fi

  ensure_jq

  local role_file="$root/data/roles/$name.json"

  if [ ! -f "$role_file" ]; then
    die "Role not found: $name"
  fi

  section "Role: $name"

  # Show description
  local desc
  desc="$(jq -r '.description // "No description"' "$role_file")"
  echo "Description: $desc"
  echo ""

  # Show tags
  echo "Tags:"
  jq -r '.tags[]? // empty' "$role_file" | while IFS= read -r tag; do
    echo "  - $tag"
  done
}
