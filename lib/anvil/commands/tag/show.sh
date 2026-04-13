#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/tags.sh
. "$SRC_ROOT/lib/anvil/tags.sh"
# shellcheck source=lib/anvil/facts.sh
. "$SRC_ROOT/lib/anvil/facts.sh"

print_usage_tag_show() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	Show details of a tag
	
	USAGE:
	    $program tag show [FLAGS] <NAME>
	
	FLAGS:
	    -h, --help              Prints help information

	ARGUMENTS:
	    <NAME>                  Name of the tag

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

cmd_tag_show() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_tag_show "$program" \
          "$default_config_path" "$default_data_home"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          help)
            print_usage_tag_show "$program" \
              "$default_config_path" "$default_data_home"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_tag_show "$program" \
              "$default_config_path" "$default_data_home" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_tag_show "$program" \
          "$default_config_path" "$default_data_home" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  if [ -n "${1:-}" ]; then
    name="$1"
  else
    print_usage_tag_show "$program" \
      "$default_config_path" "$default_data_home" >&2
    die "required argument: NAME"
  fi

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"

  local tag_file
  tag_file="$(tags_path_for "$config_file" "$data_home" "$name")"

  if [ ! -f "$tag_file" ]; then
    die "Tag not found: $name"
  fi

  ensure_jq

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
  packages="$(
    tags_packages_for \
      "$config_file" \
      "$data_home" \
      "$name" \
      "$os" \
      "$arch" \
      "homebrew"
  )"

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
