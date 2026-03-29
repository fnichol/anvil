#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"

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
# * `@param [String]` root directory path
# * `@param [String]` role name
# * `@stdout` role file path
# * `@return 0` if successful
roles_path_for() {
  local root="$1"
  local name="$2"

  echo "$(roles_path "$root")/$name.json"
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

# Resolves role dependencies and returns roles in dependency order.
#
# * `@param [String]` root directory path
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
  local root="$1"
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
    role_file="$(roles_path_for "$root" "$role")"

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
# * `@param [String]` root directory path
# * `@param [String]` role name
# * `@stdout` space-delimited list of tag names
# * `@return 0` if successful
# * `@return 1` if role file not found
roles_tags_for() {
  local root="$1"
  local name="$2"

  ensure_jq

  local role_file
  role_file="$(roles_path_for "$root" "$name")"

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
