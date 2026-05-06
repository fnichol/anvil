#!/usr/bin/env sh
# shellcheck disable=SC3043

# Import cookie to prevent circular loading
if [ -n "${__ANVIL_SOURCED_ARGPARSE__:-}" ]; then
  return 0
else
  __ANVIL_SOURCED_ARGPARSE__=true
fi

usage_and_die() {
  usage >&2
  die "$1"
}

ensure_required_arg() {
  case "${2:-}" in
    "" | -?*)
      usage_and_die "missing required argument for $1 option"
      ;;
  esac
}
