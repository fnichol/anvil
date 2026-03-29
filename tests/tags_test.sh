#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  commonOneTimeSetUp

  . "${0%/*}/../vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/tags.sh}"
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

testTagsHooksForReturnsNothingWhenNoHooksSection() {
  # delta.json has no hooks key
  run tags_hooks_for "${0%/*}/fixtures" delta arch x86_64 finalize

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testTagsHooksForReturnsHooksForMatchingOs() {
  run tags_hooks_for "${0%/*}/fixtures" foxtrot arch x86_64 finalize

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apple"
  assertStdoutContains "cranberry"
  assertStderrNull
}

testTagsHooksForReturnsNothingForNonMatchingOs() {
  run tags_hooks_for "${0%/*}/fixtures" foxtrot macos x86_64 finalize

  assertTrue 'function failed' "$return_status"
  # only "all/all" bucket matches — cranberry
  assertStdoutContains "cranberry"
  assertFalse 'apple should not appear' \
    "grep -q 'apple' '$stdout'"
  assertStderrNull
}

testTagsHooksForReturnsAllOsWildcardOnEveryPlatform() {
  run tags_hooks_for "${0%/*}/fixtures" foxtrot ubuntu x86_64 finalize

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "cranberry"
  assertStderrNull
}

testTagsHooksForReturnsMultipleHooksForMatchingOs() {
  run tags_hooks_for "${0%/*}/fixtures" foxtrot cachyos x86_64 finalize

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apple"
  assertStdoutContains "banana"
  assertStdoutContains "cranberry"
  assertStderrNull
}

testTagsHooksForReturnsHooksForConfigurePhase() {
  run tags_hooks_for "${0%/*}/fixtures" foxtrot arch x86_64 configure

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "eggplant"
  assertStderrNull
}

testTagsHooksForReturnsNothingForPhaseWithNoHooks() {
  run tags_hooks_for "${0%/*}/fixtures" foxtrot arch x86_64 install

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testTagsResolveWithObjectStyleDependsOn() {
  run tags_resolve "${0%/*}/fixtures" golf

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "alfa bravo charlie golf"
  assertStderrNull
}

testTagsPackagesForWithObjectStyleEntry() {
  run tags_packages_for "${0%/*}/fixtures" golf macos aarch64 homebrew

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "mango"
  assertStdoutContains "papaya"
  assertStderrNull
}

testTagsHooksForWithObjectStyleEntry() {
  run tags_hooks_for "${0%/*}/fixtures" golf arch x86_64 finalize

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "fig"
  assertStdoutContains "guava"
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "$shunit2"
