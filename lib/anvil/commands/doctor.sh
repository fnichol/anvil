#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
# shellcheck source=lib/anvil/config.sh
. "$SRC_ROOT/lib/anvil/config.sh"
# shellcheck source=lib/anvil/modules.sh
. "$SRC_ROOT/lib/anvil/modules.sh"
# shellcheck source=lib/anvil/tags.sh
. "$SRC_ROOT/lib/anvil/tags.sh"
# shellcheck source=lib/anvil/facts.sh
. "$SRC_ROOT/lib/anvil/facts.sh"
# shellcheck source=lib/anvil/jq.sh
. "$SRC_ROOT/lib/anvil/jq.sh"
# shellcheck source=lib/anvil/script.sh
. "$SRC_ROOT/lib/anvil/script.sh"

__ANVIL_REQUIRED_CMDS=""
__ANVIL_REQUIRED_CMDS_ALPINE="apk wget"
__ANVIL_REQUIRED_CMDS_ARCH="curl pacman"
__ANVIL_REQUIRED_CMDS_DEBIAN="apt wget"
__ANVIL_REQUIRED_CMDS_MACOS="xcode-select curl"

print_usage_doctor() {
  local program="$1"
  local default_config_path="$2"
  local default_data_home="$3"

  cat <<-EOF
	Verify system health and requirements

	USAGE:
	    $program doctor [FLAGS]

	FLAGS:
	    -h, --help       Prints help information

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	    ANVIL_DATA_HOME         [default: $default_data_home]
	EOF
}

cmd_doctor() {
  local program
  program="$1"
  shift

  local default_config_path config_file
  default_config_path="$(config_path)"
  local default_data_home data_home
  default_data_home="$(modules_data_home)"

  usage() {
    print_usage_doctor \
      "$program" \
      "$default_config_path" \
      "$default_data_home"
  }

  while [ $# -gt 0 ]; do
    case "$1" in
      # Flags
      -h | --help)
        usage
        return 0
        ;;
      # Parsing
      --) # explicitly terminates argument processing
        shift 1
        break
        ;;
      -?*)
        usage_and_die "invalid argument $1"
        ;;
      *)
        break
        ;;
    esac
  done

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"
  data_home="${ANVIL_DATA_HOME:-$default_data_home}"

  section "Anvil Doctor - System Health Check"

  local issues=0

  # Check for required commands
  section "Required Commands"

  for cmd in $__ANVIL_REQUIRED_CMDS; do
    if check_cmd "$cmd"; then
      info "✓ $cmd found: $(command -v "$cmd")"
    else
      warn "✗ $cmd not found (required)"
      issues=$((issues + 1))
    fi
  done
  echo ""

  # Check platform-specific requirements
  local os
  os="$(facts_os)"

  section "Platform-Specific ($os)"

  local platform_required_cmds=""
  case "$os" in
    alpine)
      platform_required_cmds="$__ANVIL_REQUIRED_CMDS_ALPINE"
      ;;
    arch | cachyos)
      platform_required_cmds="$__ANVIL_REQUIRED_CMDS_ARCH"
      ;;
    debian | ubuntu)
      platform_required_cmds="$__ANVIL_REQUIRED_CMDS_DEBIAN"
      ;;
    macos)
      platform_required_cmds="$__ANVIL_REQUIRED_CMDS_MACOS"
      ;;
  esac

  if [ -n "$platform_required_cmds" ]; then
    for cmd in $platform_required_cmds; do
      if check_cmd "$cmd"; then
        info "✓ $cmd found: $(command -v "$cmd")"
      else
        warn "✗ $cmd not found (required)"
        issues=$((issues + 1))
      fi
    done
  else
    info "✓ no extra commands needed"
  fi

  ensure_jq
  ensure_script

  echo ""

  # Check config
  section "Configuration"

  if config_exists "$config_file"; then
    info "✓ Config found: $config_file"

    # Validate JSON
    if jq empty "$config_file" 2>/dev/null; then
      info "✓ Config is valid JSON"
    else
      warn "✗ Config has invalid JSON syntax"
      issues=$((issues + 1))
    fi

    # Check for tags
    local tags
    tags="$(config_read_tags "$config_file" 2>/dev/null || echo "")"
    if [ -n "$tags" ]; then
      info "✓ Config has tags defined: $tags"
    else
      warn "○ Config has no tags (optional but recommended)"
    fi
  else
    info "○ No config file (optional)"
    info "  Create: $program config init"
  fi
  echo ""

  section "Modules"

  if config_exists "$config_file"; then
    local module_count
    module_count="$(jq '.modules | length' "$config_file")"

    info "✓ Found $module_count module(s)"

    local roles role_count
    roles="$(roles_list_all "$config_file" "$data_home")"
    if [ -n "$roles" ]; then
      role_count="$(echo "$roles" | wc -l | tr -d ' ')"
    else
      role_count=0
    fi
    info "✓ Found $role_count active installed role definition(s)"

    local tags tag_count
    tags="$(tags_list_all "$config_file" "$data_home")"
    if [ -n "$tags" ]; then
      tag_count="$(echo "$tags" | wc -l | tr -d ' ')"
    else
      tag_count=0
    fi
    info "✓ Found $tag_count active installed tag definition(s)"
  else
    info "○ No modules as no config file present (optional)"
  fi
  echo ""

  # Summary
  section "Summary"
  if [ "$issues" -eq 0 ]; then
    info "✓ No issues found - system is healthy"
    return 0
  else
    warn "Found $issues issue(s) - please resolve before using anvil"
    return 1
  fi
}
