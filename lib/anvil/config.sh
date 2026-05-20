#!/usr/bin/env sh
# shellcheck disable=SC3043

# Import cookie to prevent circular loading
if [ -n "${__ANVIL_SOURCED_CONFIG__:-}" ]; then
  return 0
else
  __ANVIL_SOURCED_CONFIG__=true
fi

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/roles.sh
. "$SRC_ROOT/lib/anvil/roles.sh"
# shellcheck source=lib/anvil/tags.sh
. "$SRC_ROOT/lib/anvil/tags.sh"

# Returns the Anvil config home directory.
#
# The path is determined using the XDG Base Directory specification, falling
# back to `~/.config` if not set.
#
# * `@stdout` data home path
# * `@return 0` if successful
#
# # Environment Variables
#
# * `XDG_CONFIG_HOME` used to determine the configuration directory, defaults
#   to `$HOME/.config` if not set
# * `HOME` used as fallback when `XDG_CONFIG_HOME` is not set
config_home() {
  echo "${XDG_CONFIG_HOME:-$HOME/.config}/anvil"
}

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
  echo "$(config_home)/config.json"
}

# Checks if a configuration file exists.
#
# * `@param [String]` configuration file path
# * `@return 0` if the configuration file exists
# * `@return 1` if the configuration file does not exist
config_exists() {
  local config_file="$1"

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
# * `@param [optional, String]` comma-separated list of role names
# * `@param [optional, String]` an FQDN for the host
# * `@stderr` warning message if file already exists
# * `@return 0` if successful
# * `@return 1` if configuration file already exists
config_create() {
  local config_file roles_str tags_str fqdn_str
  config_file="$1"
  tags_str="$2"
  roles_str="${3:-}"
  fqdn_str="${4:-}"

  if config_exists "$config_file"; then
    warn "Can't create new config, file already exists: $config_file"
    return 1
  fi

  mkdir -p "$(dirname "$config_file")"

  touch "$config_file"
  config_create_json "$tags_str" "$roles_str" "$fqdn_str" >"$config_file"
}

# Generates JSON configuration data.
#
# This function creates a JSON structure with tags array, skip_steps array, and
# custom_packages object. The input tag string is split on commas and trimmed
# of whitespace.
#
# * `@param [String]` comma-separated list of tag names
# * `@param [optional, String]` comma-separated list of role names
# * `@param [optional, String]` an FQDN for the host
# * `@stdout` JSON configuration data
# * `@return 0` if successful
# * `@return 1` if `jq` command is not available
#
# # Examples
#
# Basic usage:
#
# ```sh
# config_create_json "base, multimedia, base-gui" "workstation" "myhost.local"
# ```
config_create_json() {
  local tags_str fqdn_str
  tags_str="$1"
  roles_str="${2:-}"
  fqdn_str="${3:-}"

  ensure_jq

  jq -n \
    --arg tags_str "$tags_str" \
    --arg roles_str "$roles_str" \
    --arg fqdn "$fqdn_str" \
    '
    (if $fqdn != "" then {fqdn: $fqdn} else {} end) +
    (if $roles_str != "" then
      {roles: $roles_str | split(",") | map(ltrimstr(" ") | rtrimstr(" "))}
     else {} end) +
    (if $tags_str != "" then
      {tags: $tags_str | split(",") | map(ltrimstr(" ") | rtrimstr(" "))}
     else {} end) +
    {
      modules: [],
      skip_steps: [],
      custom_packages: {
        add: [],
        remove: []
      }
    }'
}

# Reads the FQDN field from a configuration file.
#
# * `@param [String]` configuration file path
# * `@stdout` FQDN value if present
# * `@return 0` if successful
config_read_fqdn() {
  local config_file="$1"

  if config_exists "$config_file"; then
    ensure_jq

    jq -r '.fqdn // empty' "$config_file"
  fi
}

# Reads the tags array from a configuration file.
#
# * `@param [String]` configuration file path
# * `@stdout` space-seperated list of tag names
# * `@return 0` if successful
config_read_tags() {
  local config_file="$1"

  if config_exists "$config_file"; then
    ensure_jq

    need_cmd tr

    jq -r '.tags[]? // empty' "$config_file" | tr '\n' ' '
  fi
}

# Reads the roles array from a configuration file.
#
# * `@param [String]` configuration file path
# * `@stdout` space-seperated list of role names
# * `@return 0` if successful
config_read_roles() {
  local config_file="$1"

  if config_exists "$config_file"; then
    ensure_jq

    jq -r '.roles[]? // empty' "$config_file" | tr '\n' ' '
  fi
}

# Reads the modules array from a configuration file.
#
# * `@param [String]` configuration file path
# * `@stdout` module names, one per line, in priority order
# * `@return 0` if successful
config_read_modules() {
  local config_file="$1"

  if config_exists "$config_file"; then
    ensure_jq

    jq -r '.modules[]?.name // empty' "$config_file"
  fi
}

# Reads the skip_steps array from a configuration file.
#
# * `@param [String]` configuration file path
# * `@stdout` list of step names to skip, one per line
# * `@return 0` if successful
config_read_skip_steps() {
  local config_file="$1"

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
# * `@param [String]` configuration file path
# * `@stdout` list of package names to add, one per line
# * `@return 0` if successful
config_read_custom_add() {
  local config_file="$1"

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
# * `@param [String]` configuration file path
# * `@stdout` list of package names to remove, one per line
# * `@return 0` if successful
config_read_custom_remove() {
  local config_file="$1"

  if config_exists "$config_file"; then
    ensure_jq

    jq -r '.custom_packages.remove[]? // empty' "$config_file"
  fi
}

# Resolves the complete tag list from a configuration file.
#
# Reads roles (if any), resolves role dependencies in order, collects their
# tags, then appends any explicit tags from the "tags" array.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@stdout` space-delimited list of tag names (role sourced first, then
#   extra tags from config)
# * `@return 0` if successful
config_resolve_tags() {
  local config_file="$1"
  local data_home="$2"

  # If no config file is found, then no tags are resolved--done
  if ! config_exists "$config_file"; then
    return 0
  fi

  need_cmd tr

  ensure_jq

  local all_tags=""

  # Load all config defined roles
  local config_roles
  config_roles="$(config_read_roles "$config_file")"

  if [ -n "$config_roles" ]; then
    # Resolve all roles to a dependencies-first ordering
    local resolved_roles
    resolved_roles="$(
      roles_resolve "$config_file" "$data_home" "$config_roles"
    )"

    # Expand roles to the appropriate set of dependencies-first ordered tags
    for role in $resolved_roles; do
      local role_tags
      role_tags="$(roles_tags_for "$config_file" "$data_home" "$role")"

      if [ -n "$role_tags" ]; then
        all_tags="${all_tags}${all_tags:+ }${role_tags}"
      fi
    done
  fi

  # Load all config defined tags
  local config_tags
  config_tags="$(config_read_tags "$config_file")"

  # Append config tags to role-resolved and derived tags
  if [ -n "$config_tags" ]; then
    all_tags="${all_tags}${all_tags:+ }${config_tags}"
  fi

  # Resolve tag dependencies so that depends_on chains are expanded
  if [ -n "$all_tags" ]; then
    # shellcheck disable=SC2086
    all_tags="$(tags_resolve "$config_file" "$data_home" $all_tags)"
  fi

  # Note: drop trailing newline, hence the use of `printf`
  printf '%s' "$all_tags"
}
