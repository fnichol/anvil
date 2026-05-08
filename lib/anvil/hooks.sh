#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/tags.sh
. "$SRC_ROOT/lib/anvil/tags.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"

# Emits hook step names for a phase, one per line, in numeric file order.
#
# Collects hook names from each resolved tag's hooks section for the given
# phase, OS, and architecture. Deduplicates across tags. Resolves each name
# to its script file (dying with an error if a declared hook is missing).
# Sorts by the NNN- numeric prefix to determine execution order.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String]` operating system (e.g. "arch", "darwin")
# * `@param [String]` architecture (e.g. "x86_64", "aarch64")
# * `@param [String]` phase name (e.g. "configure", "finalize")
# * `@param [String]` space-separated list of resolved tag names
# * `@stdout` hook step names, one per line
# * `@return 0` always (missing/empty dir is not an error)
hooks_steps_for_phase() {
  local config_file="$1"
  local data_home="$2"
  local os="$3"
  local arch="$4"
  local phase="$5"
  local resolved_tags="$6"

  local collected=""
  local tag hook_name

  for tag in $resolved_tags; do
    for hook_name in $(
      tags_hooks_for "$config_file" "$data_home" "$tag" "$os" "$arch" "$phase"
    ); do
      case " $collected " in
        *" $hook_name "*) ;;
        *)
          collected="${collected:+$collected }$hook_name"
          ;;
      esac
    done
  done

  if [ -z "$collected" ]; then
    return 0
  fi

  local sortable=""
  for hook_name in $collected; do
    local script_path base prefix

    script_path="$(
      hooks_script_for_name "$config_file" "$data_home" "$phase" "$hook_name"
    )" || return 1
    base="${script_path##*/}"
    prefix="${base%%-*}"
    sortable="${sortable}${prefix} ${hook_name}\n"
  done

  local _prefix name
  printf "%b" "$sortable" | sort -n | while IFS=' ' read -r _prefix name; do
    normalized="$(echo "$name" | tr '-' '_')"
    echo "hook_${normalized}"
  done
}

# Emits hook directories for a phase across all installed modules.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String]` phase name
# * `@stdout` directory paths, one per line
hooks_dirs_for_phase() {
  local config_file="$1"
  local data_home="$2"
  local phase="$3"

  local module_name
  modules_installed_names "$config_file" "$data_home" \
    | while IFS= read -r module_name; do
      local hooks_dir

      hooks_dir="$(module_path_for "$data_home" "$module_name")/hooks/$phase"

      if [ -d "$hooks_dir" ]; then
        echo "$hooks_dir"
      fi
    done
}

# Emits full path to the hook script for a given step name.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String]` phase name (e.g. "configure", "finalize")
# * `@param [String]` step name without the "hook_" prefix (e.g. "tailscaled")
# * `@stdout` absolute path to the hook script file
# * `@return 0` if found
# * `@return 1` if not found
hooks_script_for_step() {
  local config_file="$1"
  local data_home="$2"
  local phase="$3"
  local step_name="$4"

  local hooks_dir

  local result
  result="$(hooks_dirs_for_phase "$config_file" "$data_home" "$phase" \
    | while IFS= read -r hooks_dir; do
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
          break
        fi
      done
    done)"

  if [ -n "$result" ]; then
    echo "$result"
    return 0
  fi

  return 1
}

# Emits full path to the hook script for a given bare hook name.
#
# The name is the filename stem without the numeric prefix and extension, with
# hyphens preserved (e.g. "tailscaled-service" matches
# "010-tailscaled-service.sh"). Dies with an error if not found.
#
# * `@param [String]` configuration file path
# * `@param [String]` data home directory path
# * `@param [String]` phase name (e.g. "configure", "finalize")
# * `@param [String]` hook name (e.g. "tailscaled-service")
# * `@stdout` absolute path to the hook script file
# * `@return 0` if found
# * `@exit` with error message if not found
hooks_script_for_name() {
  local config_file="$1"
  local data_home="$2"
  local phase="$3"
  local name="$4"

  result="$(hooks_dirs_for_phase "$config_file" "$data_home" "$phase" \
    | while IFS= read -r hooks_dir; do
      local filename base candidate

      for filename in "$hooks_dir"/[0-9]*-*.sh; do
        [ -f "$filename" ] || continue
        base="${filename##*/}"
        candidate="${base#*-}"
        candidate="${candidate%.sh}"
        if [ "$candidate" = "$name" ]; then
          echo "$filename"
          break
        fi
      done
    done)"

  if [ -n "$result" ]; then
    echo "$result"
    return 0
  fi

  warn "Hook '$name' declared in a tag but script not found in any module" >&2
  return 1
}
