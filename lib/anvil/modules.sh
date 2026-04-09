#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"

# Returns the Anvil data home directory.
#
# The path is determined using the XDG Base Directory specification, falling
# back to `~/.local/state` if not set.
#
# * `@stdout` data home path
# * `@return 0` if successful
#
# # Environment Variables
#
# * `XDG_STATE_HOME` used to determine the state directory home, defaults to
#   `$HOME/.local/state` if not set
# * `HOME` used as fallback when `XDG_STATE_HOME` is not set
modules_data_home() {
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/anvil"
}

# Returns the path to the modules directory.
#
# * `@stdout` modules directory path
modules_path() {
  echo "$(modules_data_home)/modules"
}

# Returns the path to a specific module's directory.
#
# * `@param [String]` module name
# * `@stdout` module directory path
module_path_for() {
  local name="$1"

  echo "$(modules_path)/$name"
}

# Returns the path to the modules lock file.
#
# * `@stdout` lock file path
modules_lock_path() {
  echo "$(config_home)/modules.lock.json"
}

# Returns whether a module directory exists on disk.
#
# * `@param [String]` module name
# * `@return 0` if installed
# * `@return 1` if not installed
module_is_installed() {
  local name="$1"

  [ -d "$(module_path_for "$name")" ]
}

# Returns installed module names in config priority order.
#
# Only returns modules whose directories are present on disk.
#
# * `@stdout` module names, one per line
modules_installed_names() {
  local config_file
  config_file="$(config_path)"

  if [ ! -f "$config_file" ]; then
    return 0
  fi

  ensure_jq

  jq -r '.modules[]?.name // empty' "$config_file" | while IFS= read -r name; do
    if module_is_installed "$name"; then
      echo "$name"
    fi
  done
}

# Returns all module names in config order, regardless of installation state.
#
# * `@stdout` module names, one per line
modules_registered_names() {
  local config_file
  config_file="$(config_path)"

  if [ ! -f "$config_file" ]; then
    return 0
  fi

  ensure_jq

  jq -r '.modules[].name // empty' "$config_file"
}

# Resolves a content file path across installed modules (first-match wins).
#
# * `@param [String]` content type directory name (e.g. "tags", "roles")
# * `@param [String]` filename (e.g. "base.json")
# * `@stdout` absolute path to the file in the winning module
# * `@return 0` if found
# * `@return 1` if not found in any module
modules_resolve_content() {
  local content_type="$1"
  local filename="$2"

  local result
  result="$(modules_installed_names | while IFS= read -r module_name; do
    local path
    path="$(module_path_for "$module_name")/$content_type/$filename"
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
# * `@param [String]` content type directory name (e.g. "tags", "roles")
# * `@stdout` absolute paths, one per line
modules_list_content() {
  local content_type="$1"

  local seen=""

  local module_name
  modules_installed_names | while IFS= read -r module_name; do
    local content_dir
    content_dir="$(module_path_for "$module_name")/$content_type"

    if [ ! -d "$content_dir" ]; then
      continue
    fi

    for file in "$content_dir"/*.json; do
      if [ -f "$file" ]; then
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
# * `@param [String]` content type (e.g. "tags", "roles")
# * `@param [String]` filename (e.g. "base.json")
# * `@stdout` lines of "<module> <path> <status>"
# * `@return 0` always
modules_resolve_content_all() {
  local content_type="$1"
  local filename="$2"

  local first=true

  local module_name
  modules_installed_names | while IFS= read -r module_name; do
    local path
    path="$(module_path_for "$module_name")/$content_type/$filename"
    if [ -f "$path" ]; then
      if "$first"; then
        echo "$module_name $path active"
        first=false
      else
        echo "$module_name $path shadowed"
      fi
    fi
  done
}
