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

print_usage_tag_list() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	List all available tags
	
	USAGE:
	    $program tag list [FLAGS]
	
	FLAGS:
	    -a, --all               Show all tags, even shadowed items
	    -h, --help              Prints help information

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

cmd_tag_list() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"

  local show_all=""

  OPTIND=1
  while getopts "ah-:" arg; do
    case "$arg" in
      a)
        show_all="true"
        ;;
      h)
        print_usage_tag_list "$program" \
          "$default_config_path" "$default_data_home"
        return 0
        ;;
      -)
        # long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          all)
            show_all="true"
            ;;
          help)
            print_usage_tag_list "$program" \
              "$default_config_path" "$default_data_home"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_tag_list "$program" \
              "$default_config_path" "$default_data_home" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_tag_list "$program" \
          "$default_config_path" "$default_data_home" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"

  ensure_jq

  section "Available Tags"

  if [ -n "$show_all" ]; then
    modules_installed_names "$config_file" "$data_home" \
      | while read -r mod_name; do
        local tags_dir
        tags_dir="$(module_path_for "$data_home" "$mod_name")/tags"

        if [ ! -d "$tags_dir" ]; then
          continue
        fi

        tags_list "$tags_dir" | while read -r tag; do
          local tag_file
          tag_file="$(module_path_for "$data_home" "$mod_name")/tags/$tag.json"

          local desc
          desc="$(jq -r '.description // "No description"' "$tag_file")"

          local active_file
          active_file="$(
            modules_resolve_content \
              "$config_file" \
              "$data_home" \
              "tags" \
              "$(basename "$tag_file")"
          )"

          if [ "$active_file" = "$tag_file" ]; then
            printf "  %-20s %-15s %-12s %s\n" \
              "$tag" \
              "$mod_name" \
              "active" \
              "$desc"
          else
            printf "  %-20s %-15s %-12s %s\n" \
              "$tag" \
              "$mod_name" \
              "(shadowed)" \
              "$desc"
          fi
        done
      done
  else
    tags_list_all "$config_file" "$data_home" | while IFS= read -r tag; do
      local tag_file
      tag_file="$(tags_path_for "$config_file" "$data_home" "$tag")"

      local mod_name
      mod_name="$(basename "$(dirname "$(dirname "$tag_file")")")"

      local desc
      desc="$(jq -r '.description // "No description"' "$tag_file")"

      printf "  %-20s %-15s %s\n" "$tag" "$mod_name" "$desc"
    done
  fi
}
