#!/usr/bin/env sh
# shellcheck disable=SC3043

REQUIRED_CMDS=""
REQUIRED_CMDS_ALPINE="apk wget"
REQUIRED_CMDS_ARCH="curl pacman"
REQUIRED_CMDS_DEBIAN="apt wget"
REQUIRED_CMDS_MACOS="xcode-select curl"

# Prints usage for the status command.
print_usage_doctor() {
  local program="$1"
  local default_config_path="$2"

  cat <<-EOF
	Verify system health and requirements

	USAGE:
	    $program doctor [FLAGS]

	FLAGS:
	    -h, --help       Prints help information

	ENVIRONMENT VARIABLES:
	    ANVIL_CONFIG_PATH       [default: $default_config_path]
	EOF
}

# Doctor command - verify system health and requirements
cmd_doctor() {
  local root program
  root="$1"
  shift
  program="$1"
  shift

  . "$root/lib/anvil/jq.sh"
  . "$root/lib/anvil/config.sh"
  . "$root/lib/anvil/facts.sh"

  local default_config_path config_file

  default_config_path="$(config_path)"

  OPTIND=1
  while getopts "h-:" arg; do
    case "$arg" in
      h)
        print_usage_doctor "$program" "$default_config_path"
        return 0
        ;;
      -)
        case "$OPTARG" in
          help)
            print_usage_doctor "$program" "$default_config_path"
            return 0
            ;;
          '')
            # "--" terminates argument processing
            break
            ;;
          *)
            print_usage_doctor "$program" "$default_config_path" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_doctor "$program" "$default_config_path" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  config_file="${ANVIL_CONFIG_PATH:-$default_config_path}"

  section "Anvil Doctor - System Health Check"

  local issues=0

  # Check for required commands
  section "Required Commands"

  for cmd in $REQUIRED_CMDS; do
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
      platform_required_cmds="$REQUIRED_CMDS_ALPINE"
      ;;
    arch | cachyos)
      platform_required_cmds="$REQUIRED_CMDS_ARCH"
      ;;
    debian | ubuntu)
      platform_required_cmds="$REQUIRED_CMDS_DEBIAN"
      ;;
    macos)
      platform_required_cmds="$REQUIRED_CMDS_MACOS"
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
  echo ""

  # Check config
  section "Configuration"

  if [ -f "$config_file" ]; then
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

  # Check data directory
  section "Data Directory"

  local tags_dir
  tags_dir="$root/data/tags"

  if [ -d "$tags_dir" ]; then
    local tag_count
    tag_count="$(
      find "$tags_dir" -maxdepth 1 -name '*.json' | wc -l | tr -d ' '
    )"
    info "✓ Found $tag_count tag definition(s) in: $tags_dir"
  else
    warn "✗ Tag directory not found: $tags_dir"
    issues=$((issues + 1))
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
