#!/usr/bin/env sh
# shellcheck disable=SC3043

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
