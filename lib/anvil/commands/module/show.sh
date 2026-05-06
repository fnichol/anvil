#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"

print_usage_module_show() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	Show details of a module

	USAGE:
	    $program module show [FLAGS] <NAME>

	FLAGS:
	    -h, --help              Prints help information

	ARGUMENTS:
	    <NAME>                  Name of the module

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

cmd_module_show() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"

  usage() {
    print_usage_module_show \
      "$program" \
      "$default_config_path" \
      "$default_data_home"
  }

  local name

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

  if [ -n "${1:-}" ]; then
    name="$1"
  else
    usage_and_die "required argument: NAME"
  fi

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"

  ensure_jq

  local config_module_json
  config_module_json="$(
    jq -r \
      --arg name "$name" \
      '.modules[]? | select(.name == $name)' \
      "$config_file"
  )"

  if [ -z "$config_module_json" ]; then
    warn "Module named '$name' not found. Try 'anvil module list'."
    return 1
  fi

  section "Module: $name"
  echo ""

  local head_pad="-30"

  # Only display extra information if module is installed
  if module_is_installed "$data_home" "$name"; then
    local mod_file
    mod_file="$(module_path_for "$data_home" "$name")/module.json"

    printf "%${head_pad}s | %s\n" \
      "Description" \
      "$(jq -r '.description // ""' "$mod_file")"

    printf "%${head_pad}s | %s\n" \
      "Min Anvil Version" \
      "$(jq -r '.min_anvil_version // ""' "$mod_file")"
  fi

  printf "%${head_pad}s | %s\n" \
    "URL" \
    "$(
      echo "$config_module_json" \
        | jq -r '.url // "Missing URL"'
    )"

  printf "%${head_pad}s | %s\n" \
    "Constraint" \
    "$(
      echo "$config_module_json" \
        | jq -r '(.branch // .tag // .commit // "(default)")'
    )"

  printf "%${head_pad}s | %s\n" \
    "Installed" \
    "$(
      if module_is_installed "$data_home" "$name"; then
        echo "yes"
      else
        echo "no"
      fi
    )"

  if ! module_is_installed "$data_home" "$name"; then
    return 0
  fi

  echo ""

  section "Roles"
  local roles_path
  roles_path="$(module_path_for "$data_home" "$name")/roles"
  if [ -d "$roles_path" ]; then
    for file in "$roles_path"/*.json; do
      local content item status

      content="$(
        modules_resolve_content_all \
          "$config_file" \
          "$data_home" \
          "roles" \
          "$(basename "$file")" \
          | grep "^$name "
      )"
      item="$(basename "$(echo "$content" | cut -d ' ' -f 2)")"
      status="$(echo "$content" | cut -d ' ' -f 3)"

      printf "  - %-26s (%s)\n" "${item%%.json}" "$status"
    done
  fi
  echo ""

  section "Tags"
  local tags_path
  tags_path="$(module_path_for "$data_home" "$name")/tags"
  if [ -d "$tags_path" ]; then
    for file in "$tags_path"/*.json; do
      local content item status

      content="$(
        modules_resolve_content_all \
          "$config_file" \
          "$data_home" \
          "tags" \
          "$(basename "$file")" \
          | grep "^$name "
      )"
      item="$(basename "$(echo "$content" | cut -d ' ' -f 2)")"
      status="$(echo "$content" | cut -d ' ' -f 3)"

      printf "  - %-26s (%s)\n" "${item%%.json}" "$status"
    done
  fi
  echo ""

  section "Hooks"
  local hooks_path
  hooks_path="$(module_path_for "$data_home" "$name")/hooks"
  if [ -d "$hooks_path" ]; then
    for phase in bootstrap configure finalize; do
      if [ -d "$hooks_path/$phase" ]; then
        echo "$phase"
        for file in "$hooks_path/$phase"/*.sh; do
          local content item status

          content="$(
            modules_resolve_content_all \
              "$config_file" \
              "$data_home" \
              "hooks/$phase" \
              "$(basename "$file")" \
              | grep "^$name "
          )"
          item="$(basename "$(echo "$content" | cut -d ' ' -f 2)")"
          status="$(echo "$content" | cut -d ' ' -f 3)"

          printf "  - %-26s (%s)\n" "${item%%.sh}" "$status"
        done
      fi
    done
  fi
}
