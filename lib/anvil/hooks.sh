#!/usr/bin/env sh
# shellcheck disable=SC3043

# Emits hook step names for a phase, one per line, in numeric file order.
#
# Files in data/hooks/<phase>/ named NNN-<name>.sh become step names of the
# form "hook_<name>". Hyphens in <name> are converted to underscores.
#
# * `@param [String]` root directory of the codebase
# * `@param [String]` phase name (e.g. "configure", "finalize")
# * `@stdout` hook step names, one per line
# * `@return 0` always (missing/empty dir is not an error)
hooks_steps_for_phase() {
  local root="$1"
  local phase="$2"

  local hooks_dir="$root/data/hooks/$phase"

  # If directory doesn't exist, early return
  if [ ! -d "$hooks_dir" ]; then
    return 0
  fi

  local filename base name
  for filename in "$hooks_dir"/[0-9]*-*.sh; do
    if [ ! -f "$filename" ]; then
      continue
    fi

    # Normalize name of hook from filename
    base="${filename##*/}"
    name="${base#*-}"
    name="${name%.sh}"
    name="$(echo "$name" | tr '-' '_')"

    echo "hook_$name"
  done
}

# Emits full path to the hook script for a given step name.
#
# * `@param [String]` root directory of the codebase
# * `@param [String]` phase name (e.g. "configure", "finalize")
# * `@param [String]` step name without the "hook_" prefix (e.g. "tailscaled")
# * `@stdout` absolute path to the hook script file
# * `@return 0` if found
# * `@return 1` if not found
hooks_script_for_step() {
  local root="$1"
  local phase="$2"
  local step_name="$3"

  local hooks_dir="$root/data/hooks/$phase"

  # If directory doesn't exist, early return
  if [ ! -d "$hooks_dir" ]; then
    return 0
  fi

  local filename base candidate
  for filename in "$hooks_dir"/[0-9]*-*.sh; do
    if [ ! -f "$filename" ]; then
      continue
    fi

    # Normalize candidate name from filename
    base="${filename##*/}"
    candidate="${base#*-}"
    candidate="${candidate%.sh}"
    candidate="$(echo "$candidate" | tr '-' '_')"

    if [ "$candidate" = "$step_name" ]; then
      echo "$filename"
      return 0
    fi
  done

  return 1
}
