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

# Checks if a modules lock file exists.
#
# * `@param [String]` modules lock file path
# * `@return 0` if the modules lock file exists
# * `@return 1` if the modules lock file does not exist
modules_lock_exists() {
  local modules_lock_file="$1"

  [ -f "$modules_lock_file" ]
}

# Creates a new modules lock file.
#
# This function creates the configuration directory if it doesn't exist, then
# generates a new lock file. If the local file already exists, this function
# returns an error.
#
# * `@param [String]` modules lock file path
# * `@stderr` warning message if file already exists
# * `@return 0` if successful
# * `@return 1` if configuration file already exists
modules_lock_create() {
  local modules_lock_file="$1"

  if modules_lock_exists "$modules_lock_file"; then
    warn \
      "Can't create modules lock, file already exists: $modules_lock_file" >&2
    return 1
  fi

  mkdir -p "$(dirname "$modules_lock_file")"
  jq -n '{modules: []}' >"$modules_lock_file"
}

# Returns the JSON object for the given module from the lock file.
#
# * `@param [String]` modules lock file path
# * `@param [String]` module name
# * `@stdout` JSON string if an entry is found and an empty string otherwise
module_lock_json_for() {
  local modules_lock_file="$1"
  local name="$2"

  if modules_lock_exists "$modules_lock_file"; then
    ensure_jq

    jq -r \
      --arg name "$name" \
      '.modules[] | select(.name == $name)' \
      "$modules_lock_file"
  fi
}

# Returns the JSON object for the given module from the config file.
#
# * `@param [String]` configuration file path
# * `@param [String]` module name
# * `@stdout` JSON string if an entry is found and an empty string otherwise
module_config_json_for() {
  local config_file="$1"
  local name="$2"

  if config_exists "$config_file"; then
    ensure_jq

    jq -r \
      --arg name "$name" \
      '.modules[] | select(.name == $name)' \
      "$config_file"
  fi
}

# Adds a named module to the config file.
#
# * `@param [String]` configuration file path
# * `@param [String]` module name
# * `@param [String]` module url
# * `@param [String]` module branch (empty string for not set)
# * `@param [String]` module commit (empty string for not set)
# * `@param [String]` module tag (empty string for not set)
module_config_add() {
  local config_file="$1"
  local name="$2"
  local url="$3"
  local branch="$4"
  local commit="$5"
  local tag="$6"

  local tmp_config
  tmp_config="$(mktemp_file)"
  cleanup_file "$tmp_config"

  local config_jq_str
  # shellcheck disable=SC2016
  config_jq_str='.modules += [{name: $name, url: $url}]'
  if [ -n "$branch" ]; then
    # shellcheck disable=SC2016
    config_jq_str='.modules += [{name: $name, url: $url, branch: $branch}]'
  fi
  if [ -n "$commit" ]; then
    # shellcheck disable=SC2016
    config_jq_str='.modules += [{name: $name, url: $url, commit: $commit}]'
  fi
  if [ -n "$tag" ]; then
    # shellcheck disable=SC2016
    config_jq_str='.modules += [{name: $name, url: $url, tag: $tag}]'
  fi

  ensure_jq

  info "Updating config file"

  jq \
    --arg name "$name" \
    --arg url "$url" \
    --arg branch "$branch" \
    --arg commit "$commit" \
    --arg tag "$tag" \
    "$config_jq_str" \
    "$config_file" \
    >"$tmp_config"
  cat "$tmp_config" >"$config_file"
}

# Removes a named entry from the config file.
#
# * `@param [String]` configuration file path
# * `@param [String]` module name
module_config_remove_for() {
  local config_file="$1"
  local name="$2"

  # Early return if config file does not exist
  if ! config_exists "$config_file"; then
    return 0
  fi

  local tmp_config
  tmp_config="$(mktemp_file)"
  cleanup_file "$tmp_config"

  ensure_jq

  info "Updating config file"

  jq \
    --arg name "$name" \
    'del(.modules[] | select(.name == $name))' \
    "$config_file" \
    >"$tmp_config"
  cat "$tmp_config" >"$config_file"
}

# Removes a named entry from the lock file.
#
# * `@param [String]` modules lock file path
# * `@param [String]` module name
module_lock_remove_for() {
  local modules_lock_file="$1"
  local name="$2"

  # Early return if lock file does not exist
  if ! modules_lock_exists "$modules_lock_file"; then
    return 0
  fi

  local tmp_lock
  tmp_lock="$(mktemp_file)"
  cleanup_file "$tmp_lock"

  ensure_jq

  info "Updating modules lock file"

  jq \
    --arg name "$name" \
    'del(.modules[] | select(.name == $name))' \
    "$modules_lock_file" \
    >"$tmp_lock"
  cat "$tmp_lock" >"$modules_lock_file"
}

# Updates the lock file entry for a module with the given Git sha.
#
# * `@param [String]` configuration file path
# * `@param [String]` modules lock file path
# * `@param [String]` module name
# * `@param [String]` git sha to checkout
# * `@return 0` if successful
# * `@return 1` if not successful
module_lock_update_for() {
  local config_file="$1"
  local modules_lock_file="$2"
  local name="$3"
  local current_sha="$4"

  local config_json
  config_json="$(module_config_json_for "$config_file" "$name")"

  if [ -z "$config_json" ]; then
    warn "No lock file entry for module named '$name'"
    return 1
  fi

  ensure_jq

  local url branch
  url="$(echo "$config_json" | jq -r '.url // empty')"
  branch="$(echo "$config_json" | jq -r '.branch // empty')"

  if [ -z "$url" ]; then
    warn "Missing configuration URL for module named '$name'"
    return 1
  fi

  local lock_json_str
  if [ -n "$branch" ]; then
    lock_json_str="$(
      jq -n -r -S \
        --arg name "$name" \
        --arg url "$url" \
        --arg commit "$current_sha" \
        --arg branch "$branch" \
        '. + {name: $name, url: $url, commit: $commit, branch: $branch}'
    )"
  else
    lock_json_str="$(
      jq -n -r -S \
        --arg name "$name" \
        --arg url "$url" \
        --arg commit "$current_sha" \
        '. + {name: $name, url: $url, commit: $commit}'
    )"
  fi

  if ! modules_lock_exists "$modules_lock_file"; then
    info "Creating modules lock file"
    modules_lock_create "$modules_lock_file"
  fi

  info "Updating modules lock file"

  local tmp_lock
  tmp_lock="$(mktemp_file)"
  cleanup_file "$tmp_lock"

  jq -r -S \
    --argjson module "$lock_json_str" \
    '
      .modules |= (
        (map(.name) | index($module.name)) as $idx |
        if $idx != null
        then .[$idx] |= . + $module
        else . + [$module]
        end
      )
    ' \
    "$modules_lock_file" \
    | jq -r '.modules |= sort_by(.name)' \
      >"$tmp_lock"
  cat "$tmp_lock" >"$modules_lock_file"
}

# Installs a module for the first time.
#
# * `@param [String]` destination modules clone directory
# * `@param [String]` clone url
# * `@param [optional, String]` optional commit to update checkout
# * `@return 0` if successful
# * `@return 1` if not successful
module_install() {
  local mod_path="$1"
  local url="$2"
  local commit="${3:-}"

  ensure_git

  info "Cloning '$(basename "$mod_path")'"
  mkdir -p "$(dirname "$mod_path")"
  indent git clone "$url" "$mod_path"

  if [ -n "$commit" ]; then
    indent git -C "$mod_path" checkout "$commit"
  fi
}

# Installs a module from state in lock file.
#
# * `@param [String]` data home directory path
# * `@param [String]` modules lock file path
# * `@param [String]` module name
# * `@return 0` if successful
# * `@return 1` if not successful
module_install_from_lock() {
  local data_home="$1"
  local modules_lock_file="$2"
  local name="$3"

  local lock_json
  lock_json="$(module_lock_json_for "$modules_lock_file" "$name")"

  if [ -z "$lock_json" ]; then
    warn "No lock file entry for module named '$name'"
    return 1
  fi

  local url commit
  url="$(echo "$lock_json" | jq -r '.url // empty')"
  commit="$(echo "$lock_json" | jq -r '.commit // empty')"

  if [ -z "$url" ]; then
    warn "Lock file entry for '$name' missing url field"
    return 1
  fi
  if [ -z "$commit" ]; then
    warn "Lock file entry for '$name' missing commit field"
    return 1
  fi

  local mod_path
  mod_path="$(module_path_for "$data_home" "$name")"

  if [ -d "$mod_path" ]; then
    if [ ! -d "$mod_path/.git" ]; then
      warn "Module directory $mod_path already exists and is not a Git repo"
      return 1
    fi
  else
    module_install "$mod_path" "$url"
  fi

  indent git -C "$mod_path" checkout "$commit"
}

module_uninstall() {
  local mod_path="$1"

  if [ -d "$mod_path" ]; then
    info "Removing '$(basename "$mod_path")'"
    rm -rf "$mod_path"
  fi
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

# Expands a short form or full URL to a canonical Git clone URL.
#
# The following short forms are supported:
# - `github.com/$owner/$repo` to `https://github.com/$owner/$repo.git`
# - `codeberg.org/$owner/$repo` to `https://codeberg.org/$owner/$repo.git`
# - `github.com:$owner/$repo` to `git@github.com:$owner/$repo.git`
# - `codeberg.org:$owner/$repo` to `git@codeberg.org:$owner/$repo.git`
#
# Note that full URLs (i.e. `https://` or `git@`) pass through with `.git`
# appended if missing.
#
# * `@param [String]` URL or short form
# * `@stdout` canonical clone URL
# * `@return 0` if successful
# * `@return 1` if unrecognized format
module_expand_url() {
  local input="$1"

  case "$input" in
    # Full https:// URL
    https://*)
      case "$input" in
        *.git)
          echo "$input"
          ;;
        *)
          echo "${input}.git"
          ;;
      esac

      return 0
      ;;

    # Full git@ SSH URL
    git@*)
      case "$input" in
        *.git)
          echo "$input"
          ;;
        *)
          echo "${input}.git"
          ;;
      esac

      return 0
      ;;

    # Short form: host:owner/repo (SSH)
    github.com:* | codeberg.org:*)
      local host rest
      host="${input%%:*}"
      rest="${input#*:}"

      case "$rest" in
        *.git)
          echo "git@${host}:${rest}"
          ;;
        *)
          echo "git@${host}:${rest}.git"
          ;;
      esac

      return 0
      ;;

    # Short form: host/owner/repo (HTTPS)
    github.com/* | codeberg.org/*)
      local host rest
      host="${input%%/*}"
      rest="${input#*/}"

      case "$rest" in
        *.git) echo "https://${host}/${rest}" ;;
        *) echo "https://${host}/${rest}.git" ;;
      esac

      return 0
      ;;
  esac

  warn "Unrecognized URL format: $input"
  warn "Expected: github.com/owner/repo, https://..., git@..., etc."
  return 1
}

# Extracts the repo name (without .git) from a clone URL.
#
# * `@param [String]` canonical clone URL
# * `@stdout` repo name
module_name_from_url() {
  local url="$1"
  local base

  case "$(basename "${url%.git}")" in
    # Attempt to detect an `https://github.com/$org/anvil-module` pattern
    anvil-module | anvil-modules)
      local org
      org="$(basename "$(dirname "$url")")"

      if [ -n "$org" ]; then
        echo "$org"
        return 0
      fi
      ;;
  esac

  # Get the last path component
  base="${url##*/}"
  # Strip .git suffix
  echo "${base%.git}"
}
