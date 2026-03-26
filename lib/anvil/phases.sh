#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/hooks.sh
. "$SRC_ROOT/lib/anvil/hooks.sh"

# Ordered phase list
__ANVIL_PHASES__="init facts prepare bootstrap update install configure finalize"

# Runs all phases in order, executing each step unless the step is skipped.
#
# * `@param [String]` root directory of the codebase
# * `@param [String]` path to config file
# * `@param [String]` space-delimited skip set of `phase:step` coordinate tokens
#
# # Global Variables
#
# * `__ANVIL_PHASES__`: the ordered list of phases to iterate through
phases_run() {
  local root="$1"
  local config_path="$2"
  local skip_coords="$3"

  local hostname os version kernel arch
  hostname=""
  os=""
  version=""
  kernel=""
  arch=""

  for phase in $__ANVIL_PHASES__; do
    # shellcheck source=/dev/null
    . "$SRC_ROOT/lib/anvil/phases/$phase.sh"

    echo
    section "Phase: $phase"

    for step in $(
      "${phase}_steps" "$root" "$config_path" "$os" "$version" "$kernel" "$arch"

    ); do
      if _should_skip_phase_step "$phase" "$step" "$skip_coords"; then
        info "Skipping $phase:$step"
        continue
      fi

      section "Step: $phase:$step"
      if echo "$step" | grep -q '^hook_'; then
        _phases_run_hook_step \
          "$phase" \
          "$step" \
          "$root" \
          "$config_path" \
          "$hostname" \
          "$os" \
          "$version" \
          "$kernel" \
          "$arch"
      else
        "${phase}_step_${step}" \
          "$root" \
          "$config_path" \
          "$hostname" \
          "$os" \
          "$version" \
          "$kernel" \
          "$arch"
      fi

      if [ -n "${__ANVIL_HOSTNAME:-}" ]; then
        hostname="$__ANVIL_HOSTNAME"
        unset __ANVIL_HOSTNAME
      fi
      if [ -n "${__ANVIL_OS:-}" ]; then
        os="$__ANVIL_OS"
        unset __ANVIL_OS
      fi
      if [ -n "${__ANVIL_VERSION:-}" ]; then
        version="$__ANVIL_VERSION"
        unset __ANVIL_VERSION
      fi
      if [ -n "${__ANVIL_KERNEL:-}" ]; then
        kernel="$__ANVIL_KERNEL"
        unset __ANVIL_KERNEL
      fi
      if [ -n "${__ANVIL_ARCH:-}" ]; then
        arch="$__ANVIL_ARCH"
        unset __ANVIL_ARCH
      fi
    done
  done
}

# Checks if a phase and step coordinate should be skipped.
#
# There are 4 supported coordinate forms, some of which have wildcard matches:
#
# - `phase:step`: an exact match
# - `phase:*`: all steps in the named phase
# - `*:step`: all steps of a name across all phases
# - `*:*`: all steps in all phases
#
# * `@param [String]` phase name
# * `@param [String]` step name
# * `@param [String]` space-seperated set of step coordinate tokens
# * `@return 0` if the step should be skipped
# * `@return 1` if the step should be run
_should_skip_phase_step() {
  local phase="$1"
  local step="$2"
  local skip_coords="$3"

  need_cmd grep
  need_cmd tr

  skip_coords="$(echo "$skip_coords" | tr ' ' '\n')"

  # Found exact match coordinate
  if echo "$skip_coords" | grep -q -E "^${phase}:${step}$"; then
    return 0
  fi

  # Found an "all steps in phase" coordinate
  if echo "$skip_coords" | grep -q -E "^${phase}:\*$"; then
    return 0
  fi

  # Found a "named step in all phases" coordinate
  if echo "$skip_coords" | grep -q -E "^\*:${step}$"; then
    return 0
  fi

  # Found a "all steps in all phases" coordinate
  if echo "$skip_coords" | grep -q -E "^\*:\*$"; then
    return 0
  fi

  # Otherwise, should not be skipped
  return 1
}

# Runs a single hook step as an isolated subprocess.
#
# Exports system facts and Anvil context into the subprocess environment inside
# a subshell so they do not leak back into the main process.
#
# * `@param [String]` phase name
# * `@param [String]` step name (e.g. "hook_tailscaled")
# * `@param [String]` root directory of the codebase
# * `@param [String]` path to config file
# * `@param [String]` system hostname
# * `@param [String]` operating system
# * `@param [String]` OS version
# * `@param [String]` kernel name
# * `@param [String]` CPU architecture
# * `@return 0` if the hook subprocess exits 0
# * `@return non-zero` if the hook subprocess exits non-zero
_phases_run_hook_step() {
  local phase="$1"
  local step="$2"
  local root="$3"
  local config_path="$4"
  local hostname="$5"
  local os="$6"
  local version="$7"
  local kernel="$8"
  local arch="$9"

  # Compute the shell interpreter to use for hook subprocesses.
  #
  # **Note**: `SHELL` is the user's login shell and `sh` is a safe fallback.
  if [ -z "${__ANVIL_SHELL__:-}" ]; then
    __ANVIL_SHELL__="${SHELL:-sh}"
  fi

  # Derive the hook function name: "hook_tailscaled" -> "tailscaled"
  local name="${step#hook_}"
  local func_name="${phase}_hook_${name}"

  local hook_script
  hook_script="$(hooks_script_for_step "$root" "$phase" "$name")"

  # Run in a subshell so ANVIL_* exports do not leak into the main process
  (
    export ANVIL_ROOT="$root"
    export ANVIL_CONFIG_PATH="$config_path"
    export ANVIL_HOSTNAME="$hostname"
    export ANVIL_OS="$os"
    export ANVIL_VERSION="$version"
    export ANVIL_KERNEL="$kernel"
    export ANVIL_ARCH="$arch"
    export __ANVIL_SUDO__="${__ANVIL_SUDO__:-}"

    "$__ANVIL_SHELL__" -c \
      ". '$SRC_ROOT/lib/anvil/hook_runner.sh' \
      && . '$hook_script' \
      && $func_name"
  )
}
