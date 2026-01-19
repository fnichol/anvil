#!/usr/bin/env sh
# shellcheck disable=SC3043

print_usage_tag_list() {
  local program="$1"

  cat <<-EOF
	List all available tags
	
	USAGE:
	    $program tag list [FLAGS]
	
	FLAGS:
	    -h, --help              Prints help information
	EOF
}

cmd_tag_list() {
  local root program
  root="$1"
  shift
  program="$1"
  shift

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_tag_list "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_tag_list "$program"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_tag_list "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_tag_list "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  . "$root/lib/anvil/tags.sh"

  section "Available Tags"

  local tags_dir
  tags_dir="$(tags_path "$root")"

  tags_list "$tags_dir" | while IFS= read -r tag; do
    local tag_file
    tag_file="$(tags_path_for "$root" "$tag")"

    local desc
    desc="$(jq -r '.description // "No description"' "$tag_file")"

    printf "  %-20s %s\n" "$tag" "$desc"
  done
}
