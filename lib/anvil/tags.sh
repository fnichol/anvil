#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"

# Returns the path to the tags directory.
#
# * `@param [String]` root directory path
# * `@stdout` tags directory path
# * `@return 0` if successful
#
# # Examples
#
# Basic usage:
#
# ```sh
# tags_dir="$(tags_path /path/to/anvil)"
# ```
tags_path() {
  local root="$1"

  echo "$root/data/tags"
}

# Returns the path to a specific tag file.
#
# * `@param [String]` root directory path
# * `@param [String]` tag name
# * `@stdout` tag file path
# * `@return 0` if successful
#
# # Examples
#
# Basic usage:
#
# ```sh
# tag_file="$(tags_path_for /path/to/anvil base)"
# ```
tags_path_for() {
  local root="$1"
  local name="$2"

  echo "$(tags_path "$root")/$name.json"
}

# Lists all available tag names from a tags directory.
#
# * `@param [String]` tags directory path
# * `@stdout` sorted list of tag names, one per line
# * `@return 0` if successful
# * `@return 1` if tags directory not found
#
# # Examples
#
# Basic usage:
#
# ```sh
# tags_list "$(tags_path /path/to/anvil)"
# ```
tags_list() {
  local tags_path="$1"

  if [ ! -d "$tags_path" ]; then
    warn "Tags path not found: $tags_path"
    return 1
  fi

  ensure_jq

  {
    for tag_file in "$tags_path"/*.json; do
      if [ -f "$tag_file" ]; then
        jq -r '.name' <"$tag_file"
      fi
    done
  } | sort
}

# Resolves tag dependencies and returns tags in dependency order.
#
# This function takes a list of requested tags and recursively resolves their
# dependencies, returning all tags in an order such that dependencies come
# before the tags that depend on them.
#
# * `@param [String]` root directory path
# * `@param [String...]` one or more requested tag names
# * `@stdout` space-separated list of tags in dependency order
# * `@return 0` if successful
# * `@return 1` if a tag file is not found
#
# # Notes
#
# The algorithm uses a depth-first search to resolve dependencies. It maintains
# a list of resolved tags and a processing queue. For each tag, it reads the
# `depends_on` field from the tag's JSON file and adds those dependencies to
# the front of the processing queue. Tags already in the resolved list are
# skipped to avoid duplicates. The final output is reversed so dependencies
# appear before dependent tags.
#
# # Examples
#
# Basic usage:
#
# ```sh
# resolved_tags="$(tags_resolve /path/to/anvil base-gui)"
# ```
tags_resolve() {
  local root="$1"
  shift
  local requested_tags="$*"

  need_cmd awk
  need_cmd sed
  need_cmd tr

  ensure_jq

  local resolved=""
  local to_process="$requested_tags"

  while [ -n "$to_process" ]; do
    local tag
    tag="$(echo "$to_process" | awk '{print $1}')"
    to_process="$(echo "$to_process" | awk '{$1=""; print $0}' | sed 's/^ *//')"

    # Skip if already resolved
    if echo "$resolved" | grep -q "\<$tag\>"; then
      continue
    fi

    local tag_file
    tag_file="$(tags_path_for "$root" "$tag")"

    if [ ! -f "$tag_file" ]; then
      warn "Tag file not found: $tag_file"
      return 1
    fi

    # Get additional dependencies
    local deps
    deps="$(jq -r '.depends_on[]? // empty' "$tag_file" | tr '\n' ' ')"

    # Add dependencies to process queue (at front)
    if [ -n "$deps" ]; then
      to_process="$deps $to_process"
    fi

    # Add this tag to resolved list
    if [ -z "$resolved" ]; then
      resolved="$tag"
    else
      resolved="$tag $resolved"
    fi
  done

  echo "$resolved"
}

# Extracts packages for a specific tag, OS, architecture, and package type.
#
# This function queries a tag's JSON file to retrieve packages matching the
# given criteria. It returns packages from both the "all" architecture and the
# specific architecture, allowing for architecture-independent packages to be
# included alongside architecture-specific ones.
#
# * `@param [String]` root directory path
# * `@param [String]` tag name
# * `@param [String]` operating system (e.g., "darwin", "arch")
# * `@param [String]` architecture (e.g., "x86_64", "arm64")
# * `@param [String]` package type (e.g., "homebrew", "apt")
# * `@stdout` list of package names, one per line
# * `@return 0` if successful
# * `@return 1` if `jq` command is not available
#
# # Examples
#
# Basic usage:
#
# ```sh
# tags_packages_for "/path/to/anvil" "base" "darwin" "arm64" "brew"
# ```
tags_packages_for() {
  local root="$1"
  local name="$2"
  local os="$3"
  local arch="$4"
  local package_type="$5"

  ensure_jq

  # Select all packages for the specific architecture and the `"all"`
  # architecture
  jq -r \
    --arg os "$os" \
    --arg arch "$arch" \
    --arg package_type "$package_type" \
    '(
        (.packages["all"].all[$package_type] // []) +
        (.packages["all"][$arch][$package_type] // []) +
        (.packages[$os].all[$package_type] // []) +
        (.packages[$os][$arch][$package_type] // [])
     )[]
    ' "$(tags_path_for "$root" "$name")"
}
