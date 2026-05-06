#!/usr/bin/env sh
# shellcheck disable=SC3043

# Base URL for project
__ANVIL_REPO_BASE__="https://github.com/fnichol/anvil"

# shellcheck source=lib/anvil/argparse.sh
. "${SRC_ROOT}/lib/anvil/argparse.sh"
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
	    -g, --git=<REF> Installs from a Git reference

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

  usage() {
    print_usage_check_update "$program"
  }

  local git_ref=""

  while [ $# -gt 0 ]; do
    case "$1" in
      # Flags
      -h | --help)
        usage
        return 0
        ;;
      # Options
      -g | --git)
        ensure_required_arg "$1" "${2:-}"
        git_ref="$2"
        shift 2
        ;;
      -g=?* | --git=?*)
        git_ref="${1#*=}"
        shift 1
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
