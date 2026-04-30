#!/usr/bin/env sh
# shellcheck disable=SC3043

# Base URL for project
__ANVIL_REPO_BASE__="https://github.com/fnichol/anvil"

# shellcheck source=lib/anvil/anvil.sh
. "$SRC_ROOT/lib/anvil/anvil.sh"

print_usage_check_update() {
  local program="$1"

  cat <<-EOF
	Updates Anvil to the latest release

	USAGE:
	    $program self update [FLAGS] [OPTIONS]

	FLAGS:
	    -h, --help      Prints help information

	OPTIONS:
	    -G, --git=<REF> Installs from a Git reference

	ENVIRONMENT VARIABLES:
	    ANVIL_FORCE_UPDATE  Forces update install
	EOF
}

cmd_self_update() {
  local program version
  program="$1"
  shift
  version="$1"
  shift

  local git_ref=""

  OPTIND=1
  while getopts "g:h-:" arg; do
    case "$arg" in
      g)
        git_ref="$OPTARG"
        ;;
      h)
        print_usage_check_update "$program"
        return 0
        ;;
      -)
        long_optarg="${OPTARG#*=}"
        case "$OPTARG" in
          git=?*)
            git_ref="$long_optarg"
            ;;
          git*)
            print_usage_check_update "$program" >&2
            die "missing required argument for --$OPTARG option"
            ;;
          help)
            print_usage_check_update "$program"
            return 0
            ;;
          '')
            break
            ;;
          *)
            print_usage_check_update "$program" >&2
            die "invalid argument --$OPTARG"
            ;;
        esac
        ;;
      \?)
        print_usage_check_update "$program" >&2
        die "invalid argument; arg=-$OPTARG"
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  if [ -z "${ANVIL_FORCE_UPDATE:-}" ]; then
    # A `.git/` directory signals a development checkout and a `.git` file
    # signals a worktree checkout.
    if [ -d "$SRC_ROOT/.git" ] || [ -f "$SRC_ROOT/.git" ]; then
      die "Updating not supported from a development checkout"
    fi
  fi

  local installs_path
  installs_path="$(anvil_installs_path)"

  if [ -n "$git_ref" ]; then
    local install_name
    install_name="git-$git_ref"

    local url
    url="$__ANVIL_REPO_BASE__/archive/$git_ref.tar.gz"

    section "Downloading '$program' from Git ref '$git_ref'"

    local work_dir
    work_dir="$(mktemp_directory)"
    cleanup_directory "$work_dir"

    download "$url" "$work_dir/$git_ref.tar.gz"

    section "Installing '$program' from Git ref '$git_ref'"
    (cd "$work_dir" && extract_asset "$git_ref.tar.gz")
    local src_path
    src_path="$(find_extracted_dir "$work_dir")"
    install_release "$src_path" "$installs_path" "$install_name" "anvil"

    section "'$program' installed from Git ref '$git_ref'"
  else
    section "Checking for latest '$program' release"

    local latest
    latest="$(latest_anvil_version)"

    if [ -z "$latest" ]; then
      warn "Could not successfully determine latest version"
      die "Update failed"
    fi

    if ! anvil_version_lt "$version" "$latest"; then
      info "Up to date"
      return 0
    fi

    info "Latest release: $latest (installed: $version)"

    local install_name
    install_name="$latest"

    local asset base
    asset="$program-$latest.tar.gz"
    base="$__ANVIL_REPO_BASE__/releases/download/v$latest"

    local work_dir
    work_dir="$(mktemp_directory)"
    cleanup_directory "$work_dir"

    section "Downloading '$program' release '$latest'"
    download "$base/$asset" "$work_dir/$asset"
    download "$base/$asset.md5" "$work_dir/$asset.md5"
    download "$base/$asset.sha256" "$work_dir/$asset.sha256"

    section "Verifying '$asset'"
    (cd "$work_dir" && verify_asset_md5 "$asset" "$asset.md5") \
      || die "Failed to verify MD5 digest"
    (cd "$work_dir" && verify_asset_sha256 "$asset" "$asset.sha256") \
      || die "Failed to verify SHA256 digest"

    section "Installing '$program' release '$latest'"
    (cd "$work_dir" && extract_asset "$asset")
    local src_path
    src_path="$(find_extracted_dir "$work_dir")"
    install_release "$src_path" "$installs_path" "$install_name" "anvil"

    section "'$program' updated from $version to $latest"
  fi
}
