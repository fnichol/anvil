#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"

print_usage_role_show() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	Show details of a role
	
	USAGE:
	    $program role show [FLAGS] <NAME>
	
	FLAGS:
	    -a, --all               Show all versions of role, even if shadowed
	    -h, --help              Prints help information

	ARGUMENTS:
	    <NAME>                  Name of the role

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

cmd_role_show() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"

  usage() {
    print_usage_role_show \
      "$program" \
      "$default_config_path" \
      "$default_data_home"
  }

  local show_all=""

  while [ $# -gt 0 ]; do
    case "$1" in
      # Flags
      -a | --all)
        show_all="true"
        shift 1
        ;;
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

  if [ -n "${1:-}" ]; then
    name="$1"
  else
    usage_and_die "required argument: NAME"
  fi

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"

  ensure_jq

  local all_role_files=""

  # Determine all role files that apply
  if [ -n "$show_all" ]; then
    local tmp_list
    tmp_list="$(mktemp_file)"
    cleanup_file "$tmp_list"

    modules_installed_names "$config_file" "$data_home" \
      | while read -r mod_name; do
        local roles_dir
        roles_dir="$(module_path_for "$data_home" "$mod_name")/roles"

        if [ ! -d "$roles_dir" ]; then
          continue
        fi

        local role_file
        role_file="$(module_path_for "$data_home" "$mod_name")/roles/$name.json"

        if [ -f "$role_file" ]; then
          echo "$role_file" >>"$tmp_list"
        fi
      done

    all_role_files="$(cat "$tmp_list")"

    if [ -z "$all_role_files" ]; then
      die "Role not found: $name"
    fi
  else
    # Only one candidate file when resolving for current active version
    local role_file
    role_file="$(roles_path_for "$config_file" "$data_home" "$name")"

    if [ ! -f "$role_file" ]; then
      die "Role not found: $name"
    fi

    all_role_files="$role_file"
  fi

  # For each matching role, render show output
  echo "$all_role_files" | while read -r role_file; do
    section "Role: $name"

    if [ -n "$show_all" ]; then
      local active_file
      active_file="$(
        modules_resolve_content \
          "$config_file" \
          "$data_home" \
          "roles" \
          "$(basename "$role_file")"
      )"

      # Show status
      if [ "$active_file" = "$role_file" ]; then
        echo "Status: active"
      else
        echo "Status: (shadowed)"
      fi
    fi

    # Show description
    local desc
    desc="$(jq -r '.description // "No description"' "$role_file")"
    echo "Description: $desc"
    echo ""

    # Show dependencies
    local deps
    deps="$(jq -r '.depends_on[]? // empty' "$role_file")"

    if [ -n "$deps" ]; then
      echo "Dependencies:"
      echo "$deps" | while IFS= read -r dep; do
        echo "  - $dep"
      done
      echo ""
    fi

    # Show tags
    echo "Tags:"
    jq -r '.tags[]? // empty' "$role_file" | while IFS= read -r tag; do
      echo "  - $tag"
    done
  done
}
