#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../vendor/lib/libsh.full.sh"
  . "${SRC:=lib/anvil/facts.sh}"

  commonOneTimeSetUp
}

setUp() {
  commonSetUp
}

testDetectHostname() {
  run facts_hostname

  assertTrue 'facts_hostname failed' "$return_status"
  # Should return a non-empty hostname
  assertTrue 'Hostname not detected' "[ -n '$(cat "$stdout")' ]"
}

testDetectOs() {
  run facts_os

  assertTrue 'facts_os failed' "$return_status"
  # Should return macos, linux, freebsd, openbsd, etc.
  assertTrue 'OS not detected' "[ -n '$(cat "$stdout")' ]"
}

testDetectVersion() {
  run facts_version

  assertTrue 'facts_version failed' "$return_status"
  # Version could be empty, so skip test
}

testDetectKernel() {
  run facts_kernel

  assertTrue 'facts_kernel failed' "$return_status"
  # Should return darwin, linux, freebsd, openbsd, etc.
  assertTrue 'Kernel not detected' "[ -n '$(cat "$stdout")' ]"
}

testDetectArch() {
  run facts_arch

  assertTrue 'facts_arch failed' "$return_status"
  # Should return x86_64, arm64, etc
  assertTrue 'Arch not detected' "[ -n '$(cat "$stdout")' ]"
}

testFactsToJson() {
  run facts_json

  assertTrue 'facts_json failed' "$return_status"
  assertTrue 'Missing hostname field' \
    "cat '$stdout' | jq -e '.hostname' >/dev/null"
  assertTrue 'Missing os field' \
    "cat '$stdout' | jq -e '.os' >/dev/null"
  assertTrue 'Missing version field' \
    "cat '$stdout' | jq -e '.version' >/dev/null"
  assertTrue 'Missing kernel field' \
    "cat '$stdout' | jq -e '.kernel' >/dev/null"
  assertTrue 'Missing arch field' \
    "cat '$stdout' | jq -e '.arch' >/dev/null"
}

shell_compat "$0"

. "$shunit2"
