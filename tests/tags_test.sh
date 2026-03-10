#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../vendor/lib/libsh.full.sh"
  . "lib/anvil/jq.sh"
  . "${SRC:=lib/anvil/tags.sh}"

  commonOneTimeSetUp
}

setUp() {
  commonSetUp
}

testTagsListAvailableTagsDefault() {
  run tags_list "$(tags_path "$root")"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "base"
  assertStdoutContains "base-gui"
  assertStdoutContains "multimedia"
  assertStderrNull
}

testTagsListAvailableTagsFixtures() {
  run tags_list "$(tags_path "${0%/*}/fixtures")"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "alfa"
  assertStdoutContains "bravo"
  assertStdoutContains "charlie"
  assertStdoutContains "delta"
  assertStderrNull
}

testTagsPathFor() {
  run tags_path_for "something/here" "coolbeans"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "something/here/data/tags/coolbeans.json"
  assertStderrNull
}

testTagsResolve() {
  run tags_resolve "${0%/*}/fixtures" delta

  assertTrue 'function failed' "$return_status"
  # Resolves in the correct order
  assertStdoutEquals "alfa bravo charlie delta"
  assertStderrNull
}

testTagsPackagesFor() {
  run tags_packages_for "${0%/*}/fixtures" delta macos aarch64 homebrew

  assertTrue 'function failed' "$return_status"
  assertTrue 'wrong number of results' "[ $(cat "$stdout" | wc -l) -eq 3 ]"
  assertStdoutContains "apple"
  assertStdoutContains "strawberry"
  assertStdoutContains "grape"
  assertStderrNull

}

testTagsPackagesForMissingArch() {
  run tags_packages_for "${0%/*}/fixtures" charlie openbsd x86_64 packages

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "pepper"
  assertStderrNull
}

testTagsPackagesForMissingAllArch() {
  run tags_packages_for "${0%/*}/fixtures" bravo bazzite x86_64 packages

  assertTrue 'function failed' "$return_status"
  assertTrue 'wrong number of results' "[ $(cat "$stdout" | wc -l) -eq 2 ]"
  assertStdoutContains "shirts"
  assertStdoutContains "shoes"
  assertStderrNull
}

testTagsPackagesForNoMathingPlatform() {
  run tags_packages_for "${0%/*}/fixtures" alfa solaris powerpc pkgsrc

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testTagsPackagesForAllOsReturnsOnEveryPlatform() {
  run tags_packages_for "${0%/*}/fixtures" echo macos aarch64 homeshick

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "fnichol/dot-echo"
  assertStdoutContains "fnichol/dot-echo-arm"
  assertStderrNull
}

testTagsPackagesForAllOsMergesWithOsSpecific() {
  run tags_packages_for "${0%/*}/fixtures" echo openbsd x86_64 homeshick

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "fnichol/dot-echo"
  assertStdoutContains "fnichol/dot-openbsd"
  assertStderrNull
}

testTagsPackagesForAllOsDoesNotPollutePmLookup() {
  run tags_packages_for "${0%/*}/fixtures" echo macos aarch64 homebrew

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

shell_compat "$0"

. "$shunit2"
