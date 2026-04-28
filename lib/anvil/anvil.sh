#!/usr/bin/env sh
# shellcheck disable=SC3043

# Import cookie to prevent circular loading
if [ -n "${__ANVIL_SOURCED_ANVIL__:-}" ]; then
  return 0
else
  __ANVIL_SOURCED_ANVIL__=true
fi

# Base API URL for project releases
__ANVIL_REPO_API_BASE__="https://api.github.com/repos/fnichol/workstation"

# shellcheck source=lib/anvil/facts.sh
. "$SRC_ROOT/lib/anvil/facts.sh"

# Returns the default path to the installs directory.
#
# The path is determined using the XDG Base Directory specification, falling
# back to `~/.local/share` if not set.
#
# * `@stdout` absolute path to the installs directory
#
# # Environment Variables
#
# * `XDG_DATA_HOME` used to determine the data directory home, defaults to
#   `$HOME/.local/share` if not set
# * `HOME` used as fallback when `XDG_DATA_HOME` is not set
anvil_installs_path() {
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/anvil/installs"
}

# Determines whether version string 1 is strictly less than version string 2.
#
# **Note**: comparison is numeric field-by-field (major, minor, patch). Both
# arguments must be in "X.Y.Z" form.
#
# * `@param [String]` version a
# * `@param [String]` version b
# * `@return 0` if a < b
# * `@return 1` if a >= b
anvil_version_lt() {
  local a="$1"
  local b="$2"

  need_cmd awk

  awk -v a="$a" -v b="$b" '
    BEGIN {
      split(a, av, ".")
      split(b, bv, ".")
      for (i = 1; i <= 3; i++) {
        if (av[i] + 0 < bv[i] + 0) exit 0
        if (av[i] + 0 > bv[i] + 0) exit 1
      }
      exit 1
    }
  '
}

# Queries the GitHub Releases API for the latest Anvil version.
#
# **Note**: returns an empty string on any network failure rather than exiting
# non-zero, so callers can treat absence as "no update info available."
#
# * `@stdout` version string without leading "v" (e.g. "0.2.0"), or empty
# * `@return 0` always
#
# # Global Variables
#
# * `__ANVIL_REPO_API_BASE__`: base API URL for project releases
latest_anvil_version() {
  local tmp_latest
  tmp_latest="$(mktemp_file)"
  cleanup_file "$tmp_latest"

  need_cmd awk

  download \
    "$__ANVIL_REPO_API_BASE__/releases/latest" \
    "$tmp_latest" \
    >/dev/null 2>&1 \
    || return 0

  awk '
    BEGIN { FS = "\""; RS = "," }
    $2 == "tag_name" { sub(/^v/, "", $4); print $4 }
  ' "$tmp_latest"
}

verify_asset_md5() {
  local asset="$1"
  local digest_file="$2"

  local kernel
  kernel="$(facts_kernel)"

  case "$kernel" in
    darwin)
      need_cmd awk
      need_cmd md5

      local expected actual
      expected="$(awk '{ print $1 }' "$digest_file")"
      actual="$(md5 "$asset" | awk '{ print $NF }')"

      if [ "$expected" = "$actual" ]; then
        indent echo "$asset: OK"
      else
        indent echo "$asset: FAILED"
        indent echo "md5: WARNING: 1 computed checksum did NOT match"
        return 1
      fi
      ;;
    freebsd | openbsd)
      need_cmd awk
      need_cmd md5

      indent md5 -c "$(awk '{ print $1 }' "$digest_file")" "$asset"
      ;;
    linux)
      need_cmd md5sum

      indent md5sum -c "$digest_file"
      ;;
    *)
      warn "Unsupported kernel: $kernel"
      return 1
      ;;
  esac
}

verify_asset_sha256() {
  local asset="$1"
  local digest_file="$2"

  local kernel
  kernel="$(facts_kernel)"

  case "$kernel" in
    darwin)
      need_cmd shasum

      indent shasum -c "$digest_file"
      ;;
    freebsd | openbsd)
      need_cmd awk
      need_cmd sha256

      indent sha256 -c "$(awk '{ print $1 }' "$digest_file")" "$asset"
      ;;
    linux)
      need_cmd sha256sum

      indent sha256sum -c "$digest_file"
      ;;
    *)
      warn "Unsupported kernel: $kernel"
      return 1
      ;;
  esac
}

extract_asset() {
  local asset="$1"

  need_cmd tar
  need_cmd zcat

  zcat "$asset" | indent tar xvf -
}

find_extracted_dir() {
  local root="$1"

  need_cmd find
  need_cmd head

  find "$root" -maxdepth 1 -mindepth 1 -type d | head -1
}

install_release() {
  local src_path="$1"
  local installs_path="$2"
  local install_name="$3"

  local dest_path current_ln
  dest_path="$installs_path/$install_name"
  current_ln="$installs_path/current"

  need_cmd cp
  need_cmd chmod
  need_cmd ln
  need_cmd mkdir

  info_start "Installing to '$dest_path'"
  mkdir -p "$dest_path"
  cp -rp "$src_path/." "$dest_path/"
  chmod +x "$dest_path/bin/anvil"
  info_end

  info_start "Setting 'current' to '$install_name'"
  ln -snf "$install_name" "$current_ln"
  info_end
}
