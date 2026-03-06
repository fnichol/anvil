#!/usr/bin/env sh
# shellcheck disable=SC3043

print_usage_tag_show() {
  local program="$1"

  cat <<-EOF
	Show details of a tag
	
	USAGE:
	    $program tag show [FLAGS] <NAME>
	
	FLAGS:
	    -h, --help              Prints help information

	ARGUMENTS:
	    <NAME>                  Name of the tag
	EOF
}

cmd_tag_show() {
  local root program
  root="$1"
  shift
  program="$1"
  shift

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_tag_show "$program"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_tag_show "$program"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_tag_show "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_tag_show "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  if [ -n "${1:-}" ]; then
    name="$1"
  else
    print_usage_tag_show "$program" >&2
    die "required argument: NAME"
  fi

  . "$root/lib/anvil/jq.sh"
  . "$root/lib/anvil/facts.sh"
  . "$root/lib/anvil/tags.sh"

  local tag_file
  tag_file="$(tags_path_for "$root" "$name")"

  if [ ! -f "$tag_file" ]; then
    die "Tag not found: $name"
  fi

  section "Tag: $name"

  # Show description
  local desc
  desc="$(jq -r '.description // "No description"' "$tag_file")"
  echo "Description: $desc"
  echo ""

  # Show dependencies
  local deps
  deps="$(jq -r '.depends_on[]? // empty' "$tag_file")"

  if [ -n "$deps" ]; then
    echo "Dependencies:"
    echo "$deps" | while IFS= read -r dep; do
      echo "  - $dep"
    done
    echo ""
  fi

  # Show packages for current platform
  local os arch
  os="$(facts_os)"
  arch="$(facts_arch)"

  section "Packages ($os/$arch)"

  local packages
  packages="$(tags_packages_for "$root" "$name" "$os" "$arch" "homebrew")"

  if [ -z "$packages" ]; then
    echo "  (none defined for this platform/architecture)"
  else
    echo "$packages" | while IFS= read -r pkg; do
      if [ -n "$pkg" ]; then
        echo "  - $pkg"
      fi
    done
  fi
}
