#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"

# Returns the Anvil data home directory.
#
# The path is determined using the XDG Base Directory specification, falling
# back to `~/.local/share` if not set.
#
# * `@stdout` data home path
# * `@return 0` if successful
#
# # Environment Variables
#
# * `XDG_DATA_HOME` used to determine the data directory home, defaults to
#   `$HOME/.local/share` if not set
# * `HOME` used as fallback when `XDG_DATA_HOME` is not set
modules_data_home() {
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/anvil"
}

# Returns the default path to the modules directory.
#
# * `@param [String]` data home directory path
# * `@stdout` modules directory path
modules_path() {
  local data_home_path="$1"

  echo "$data_home_path/modules"
}

# Returns the path to a specific module's directory.
#
# * `@param [String]` data home directory path
# * `@param [String]` module name
# * `@stdout` module directory path
module_path_for() {
  local data_home="$1"
  local name="$2"

  echo "$(modules_path "$data_home")/$name"
}

# Returns the default path to the modules lock file.
#
# The path is determined using the XDG Base Directory specification, falling
# back to `~/.config` if `XDG_CONFIG_HOME` is not set.
#
# * `@stdout` configuration file path
# * `@return 0` if successful
#
# # Environment Variables
#
# * `XDG_CONFIG_HOME` used to determine the configuration directory, defaults
#   to `$HOME/.config` if not set
# * `HOME` used as fallback when `XDG_CONFIG_HOME` is not set
modules_lock_path() {
  echo "$(config_home)/modules.lock.json"
}

# Returns whether a module directory exists on disk.
#
# * `@param [String]` data home directory path
# * `@param [String]` module name
# * `@return 0` if installed
# * `@return 1` if not installed
module_is_installed() {
  local data_home="$1"
  local name="$2"

  [ -d "$(module_path_for "$data_home" "$name")" ]
}

# Returns installed module names in config priority order.
#
# Only returns modules whose directories are present on disk.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@stdout` module names, one per line
modules_installed_names() {
  local config_file="$1"
  local data_home="$2"

  if ! config_exists "$config_file"; then
    return 0
  fi

  ensure_jq

  jq -r '.modules[]?.name // empty' "$config_file" | while IFS= read -r name; do
    if module_is_installed "$data_home" "$name"; then
      echo "$name"
    fi
  done
}

# Returns all module names in config order, regardless of installation state.
#
# * `@param [String]` configuration file path
# * `@stdout` module names, one per line
modules_registered_names() {
  local config_file="$1"

  if ! config_exists "$config_file"; then
    return 0
  fi

  ensure_jq

  jq -r '.modules[].name // empty' "$config_file"
}

# Resolves a content file path across installed modules (first-match wins).
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String]` content type directory name (e.g. "tags", "roles")
# * `@param [String]` filename (e.g. "base.json")
# * `@stdout` absolute path to the file in the winning module
# * `@return 0` if found
# * `@return 1` if not found in any module
modules_resolve_content() {
  local config_file="$1"
  local data_home="$2"
  local content_type="$3"
  local filename="$4"

  local result
  result="$(modules_installed_names "$config_file" "$data_home" \
    | while IFS= read -r mod_name; do
      local path
      path="$(module_path_for "$data_home" "$mod_name")/$content_type/$filename"

      if [ -f "$path" ]; then
        echo "$path"
        break
      fi
    done)"

  if [ -n "$result" ]; then
    echo "$result"
    return 0
  fi

  return 1
}

# Resolves all content files of a given type across modules, deduplicating by
# filename (first-match wins).
#
# Emits absolute paths one per line.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String]` content type directory name (e.g. "tags", "roles")
# * `@stdout` absolute paths, one per line
modules_list_content() {
  local config_file="$1"
  local data_home="$2"
  local content_type="$3"

  local seen=""

  local mod_name
  modules_installed_names "$config_file" "$data_home" \
    | while IFS= read -r mod_name; do
      local content_dir
      content_dir="$(module_path_for "$data_home" "$mod_name")/$content_type"

      if [ ! -d "$content_dir" ]; then
        continue
      fi

      for file in "$content_dir"/*.json; do
        if [ ! -f "$file" ]; then
          continue
        fi

        local basename
        basename="${file##*/}"
        case " $seen " in
          *" $basename "*) ;;
          *)
            seen="$seen $basename"
            echo "$file"
            ;;
        esac
      done
    done
}

# Resolves all occurrences of a content file across modules, including shadowed
# entries.
#
# Emits lines of the form: `<module_name> <path> <status>` where `<status>` is
# "active" for the first match and "shadowed" for subsequent.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String]` content type (e.g. "tags", "roles")
# * `@param [String]` filename (e.g. "base.json")
# * `@stdout` lines of "<module> <path> <status>"
# * `@return 0` always
modules_resolve_content_all() {
  local config_file="$1"
  local data_home="$2"
  local content_type="$3"
  local filename="$4"

  local first=true

  local mod_name
  modules_installed_names "$config_file" "$data_home" \
    | while IFS= read -r mod_name; do
      local path
      path="$(module_path_for "$data_home" "$mod_name")/$content_type/$filename"

      if [ -f "$path" ]; then
        if "$first"; then
          echo "$mod_name $path active"
          first=false
        else
          echo "$mod_name $path shadowed"
        fi
      fi
    done
}
