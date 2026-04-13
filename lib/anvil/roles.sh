#!/usr/bin/env sh
# shellcheck disable=SC3043

# Import cookie to prevent circular loading
if [ -n "${__ANVIL_SOURCED_ROLES__:-}" ]; then
  return 0
else
  __ANVIL_SOURCED_ROLES__=true
fi

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"

# **DEPRECATED**: use `modules_list_content` instead.
#
# FIXME: Remove
#
# Returns the path to the roles directory.
#
# * `@param [String]` root directory path
# * `@stdout` roles directory path
# * `@return 0` if successful
roles_path() {
  local root="$1"

  echo "$root/data/roles"
}

# Returns the path to a specific role file.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String]` role name
# * `@stdout` role file path
# * `@return 0` if successful
roles_path_for() {
  local config_file="$1"
  local data_home="$2"
  local name="$3"

  modules_resolve_content "$config_file" "$data_home" "roles" "$name.json"
}

# Lists all available role names from a roles directory.
#
# * `@param [String]` roles directory path
# * `@stdout` sorted list of role names, one per line
# * `@return 0` if successful
# * `@return 1` if roles directory not found
roles_list() {
  local roles_path="$1"

  if [ ! -d "$roles_path" ]; then
    warn "Roles path not found: $roles_path"
    return 1
  fi

  ensure_jq

  {
    for role_file in "$roles_path"/*.json; do
      if [ -f "$role_file" ]; then
        jq -r '.name' <"$role_file"
      fi
    done
  } | sort
}

# Lists all available role names across all installed modules, deduplicated.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@stdout` sorted list of role names, one per line
# * `@return 0` if successful
roles_list_all() {
  local config_file="$1"
  local data_home="$2"

  modules_list_content "$config_file" "$data_home" "roles" \
    | while IFS= read -r file; do
      jq -r '.name' <"$file"
    done \
    | sort
}

# Resolves role dependencies and returns roles in dependency order.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String...]` one or more requested role names
# * `@stdout` space-separated list of roles in dependency order
# * `@return 0` if successful
# * `@return 1` if a role file is not found
#
# # Notes
#
# The algorithm used here is the same depth-first queue algorithm as
# `tags_resolve`. That is, dependencies come before the roles that depend on
# them.
roles_resolve() {
  local config_file="$1"
  shift
  local data_home="$1"
  shift
  local requested_roles="$*"

  need_cmd awk
  need_cmd sed
  need_cmd tr

  local resolved=""
  local to_process="$requested_roles"

  while [ -n "$to_process" ]; do
    local role
    role="$(echo "$to_process" | awk '{print $1}')"
    to_process="$(echo "$to_process" | awk '{$1=""; print $0}' | sed 's/^ *//')"

    # Skip if already resolved
    if echo "$resolved" | grep -q -E "(^| )$role($| )"; then
      continue
    fi

    local role_file
    role_file="$(roles_path_for "$config_file" "$data_home" "$role")"

    if [ ! -f "$role_file" ]; then
      warn "Role file not found: $role_file"
      return 1
    fi

    # Get role dependencies
    local deps
    deps="$(
      jq -r \
        '.depends_on[]? // empty | if type == "string" then . else .name end' \
        "$role_file" \
        | tr '\n' ' '
    )"

    # Add dependencies to process queue (at front)
    if [ -n "$deps" ]; then
      to_process="$deps $to_process"
    fi

    # Add this role to resolved list
    if [ -z "$resolved" ]; then
      resolved="$role"
    else
      resolved="$role $resolved"
    fi
  done

  echo "$resolved"
}

# Returns the tags declared directly by a single role with no resolution.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String]` role name
# * `@stdout` space-delimited list of tag names
# * `@return 0` if successful
# * `@return 1` if role file not found
roles_tags_for() {
  local config_file="$1"
  local data_home="$2"
  local name="$3"

  ensure_jq

  local role_file
  role_file="$(roles_path_for "$config_file" "$data_home" "$name")"

  if [ ! -f "$role_file" ]; then
    warn "Role file not found: $role_file"
    return 1
  fi

  need_cmd tr

  jq -r \
    '.tags[]? // empty | if type == "string" then . else .name end' \
    "$role_file" \
    | tr '\n' ' '
}
