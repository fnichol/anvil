#!/usr/bin/env sh
# shellcheck disable=SC3043

# Ordered phase list
__ANVIL_PHASES__="init facts prepare bootstrap update install configure finalize"

# Runs all phases in order, executing each step unless the step is skipped.
#
# * `@param [String]` root directory of the codebase
# * `@param [String]` space-delimited skip set of `phase:step` coordinate tokens
#
# # Global Variables
#
# * `__ANVIL_PHASES__`: the ordered list of phases to iterate through
phases_run() {
  local root="$1"
  local skip_coords="$2"

  local hostname os version kernel arch
  hostname=""
  os=""
  version=""
  kernel=""
  arch=""

  for phase in $__ANVIL_PHASES__; do
    # shellcheck source=/dev/null
    . "$root/lib/anvil/phases/$phase.sh"

    section "Phase: $phase"

    for step in $("${phase}_steps"); do
      if _should_skip_phase_step "$phase" "$step" "$skip_coords"; then
        info "  Skipping $phase:$step"
        continue
      fi

      info "  Running $phase:$step"
      "${phase}_step_${step}" \
        "$root" \
        "$hostname" \
        "$os" \
        "$version" \
        "$kernel" \
        "$arch"

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
