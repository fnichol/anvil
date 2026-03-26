#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/../_ksh_local.sh"

oneTimeSetUp() {
  TEST_ROOT="${0%/*}/../.."

  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/phases/prepare.sh}"
}

testPrepareStepHostnameNoopWhenNoFqdn() {
  local config_path="$tmpdir/config.json"
  local hostname="current-host"
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  cat <<-EOF >"$config_path"
	{}
	EOF

  run prepare_step_hostname \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testPrepareStepHostnameNoopWhenFqdnMatchesCurrent() {
  local config_path="$tmpdir/config.json"
  local hostname="host.local"
  local os="alpine"
  local version="3.23.3"
  local kernel="linux"
  local arch="x86_64"

  cat <<-EOF >"$config_path"
	{
	  "fqdn": "host.local"
	}
	EOF

  # Override facts_hostname to return the configured fqdn
  # shellcheck disable=SC2329
  facts_hostname() { echo "host.local"; }

  run prepare_step_hostname \
    "$root" "$config_path" "$hostname" "$os" "$version" "$kernel" "$arch"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/../test_helpers.sh"

shell_compat "$0"

. "${0%/*}/../../$shunit2RelRoot"
