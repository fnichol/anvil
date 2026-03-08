#!/usr/bin/env sh
# shellcheck disable=SC3043

# Returns the default configuration file path.
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
config_path() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/anvil"

  echo "$config_dir/config.json"
}

# Checks if a configuration file exists.
#
# * `@param [String]` configuration file path (optional, defaults to
#   `config_path` output)
# * `@return 0` if the configuration file exists
# * `@return 1` if the configuration file does not exist
config_exists() {
  local config_file="${1:-$(config_path)}"

  [ -f "$config_file" ]
}

# Creates a new configuration file.
#
# This function creates the configuration directory if it doesn't exist, then
# generates a new configuration file with the provided comma-separated tags.
# If the configuration file already exists, this function returns an error.
#
# * `@param [String]` configuration file path
# * `@param [String]` comma-separated list of tag names
# * `@stderr` warning message if file already exists
# * `@return 0` if successful
# * `@return 1` if configuration file already exists
config_create() {
  local config_file tags_str
  config_file="$1"
  tags_str="$2"

  if config_exists "$config_file"; then
    warn "Can't create new config, file already exists: $config_file"
    return 1
  fi

  mkdir -p "$(dirname "$config_file")"

  touch "$config_file"
  config_create_json "$tags_str" >"$config_file"
}

# Generates JSON configuration data.
#
# This function creates a JSON structure with tags array, skip_steps array, and
# custom_packages object. The input tag string is split on commas and trimmed
# of whitespace.
#
# * `@param [String]` comma-separated list of tag names
# * `@stdout` JSON configuration data
# * `@return 0` if successful
# * `@return 1` if `jq` command is not available
#
# # Examples
#
# Basic usage:
#
# ```sh
# config_create_json "base, multimedia, base-gui"
# ```
config_create_json() {
  local tags_str
  tags_str="$1"

  ensure_jq

  jq -n --arg tags_str "$tags_str" '{
    tags: $tags_str | split(",") | map(ltrimstr(" ") | rtrimstr(" ")),
    skip_steps: [],
    custom_packages: {
      add: [],
      remove: []
    }
  }'
}

# Reads the FQDN field from a configuration file.
#
# * `@param [optional, String]` configuration file path (optional, defaults to
#   `config_path` output)
# * `@stdout` FQDN value if present
# * `@return 0` if successful
config_read_fqdn() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    ensure_jq

    jq -r '.fqdn // empty' "$config_file"
  fi
}

# Reads the tags array from a configuration file.
#
# * `@param [optional, String]` configuration file path (optional, defaults to
#   `config_path` output)
# * `@stdout` space-seperated list of tag names
# * `@return 0` if successful
config_read_tags() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    ensure_jq

    need_cmd tr

    jq -r '.tags[]? // empty' "$config_file" | tr '\n' ' '
  fi
}

# Reads the role field from a configuration file.
#
# * `@param [optional, String]` configuration file path (optional, defaults to
#   `config_path` output)
# * `@stdout` role value if present
# * `@return 0` if successful
config_read_role() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    ensure_jq

    jq -r '.role // empty' "$config_file"
  fi
}

# Reads the skip_steps array from a configuration file.
#
# * `@param [optional, String]` configuration file path (optional, defaults to
#   `config_path` output)
# * `@stdout` list of step names to skip, one per line
# * `@return 0` if successful
config_read_skip_steps() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    ensure_jq

    jq -r '.skip_steps[]? // empty' "$config_file"
  fi
}

# Reads custom packages to add from a configuration file.
#
# This function extracts the custom_packages.add array which contains
# additional packages to install beyond those defined in tags.
#
# * `@param [optional, String]` configuration file path (optional, defaults to
#   `config_path` output)
# * `@stdout` list of package names to add, one per line
# * `@return 0` if successful
config_read_custom_add() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    ensure_jq

    jq -r '.custom_packages.add[]? // empty' "$config_file"
  fi
}

# Reads custom packages to remove from a configuration file.
#
# This function extracts the custom_packages.remove array which contains
# packages to exclude from installation even if defined in tags.
#
# * `@param [optional, String]` configuration file path (optional, defaults to
#   `config_path` output)
# * `@stdout` list of package names to remove, one per line
# * `@return 0` if successful
config_read_custom_remove() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    ensure_jq

    jq -r '.custom_packages.remove[]? // empty' "$config_file"
  fi
}
