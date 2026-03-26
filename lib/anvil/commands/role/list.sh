#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"

print_usage_role_list() {
  local program="$1"

  cat <<-EOF
	List all available roles
	
	USAGE:
	    $program role list [FLAGS]
	
	FLAGS:
	    -h, --help              Prints help information
	EOF
}

cmd_role_list() {
  local root program
  root="$1"
  shift
  program="$1"
  shift

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_role_list "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_role_list "$program"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_role_list "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_role_list "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  ensure_jq

  need_cmd basename
  need_cmd ls

  section "Available Roles"

  local roles_dir="$root/data/roles"

  if [ ! -d "$roles_dir" ] || [ -z "$(ls -A "$roles_dir" 2>/dev/null)" ]; then
    info "No roles defined yet"
    return 0
  fi

  for role_file in "$roles_dir"/*.json; do
    if [ -f "$role_file" ]; then
      local role
      role="$(basename "$role_file" .json)"

      local desc
      desc="$(jq -r '.description // "No description"' "$role_file")"

      printf "  %-20s %s\n" "$role" "$desc"
    fi
  done
}
