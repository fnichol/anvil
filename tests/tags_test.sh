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

  data_home="$(modules_data_home)"

  # Copy over fixtures with an `apple` module by default for tests
  writeModuleFixture "apple" "$root/tests/fixtures/data/tags"
  writeConfigFile \
    '{"modules":[{"name":"apple","url":"https://example.com/a.git"}]}'
}

testTagsResolve() {
  run tags_resolve "$(config_path)" "$data_home" delta

  assertTrue 'function failed' "$return_status"
  # Resolves in the correct order
  assertStdoutEquals "alfa bravo charlie delta"
  assertStderrNull
}

testTagsPackagesFor() {
  run tags_packages_for "$(config_path)" "$data_home" \
    delta macos aarch64 homebrew

  assertTrue 'function failed' "$return_status"
  assertTrue 'wrong number of results' "[ $(cat "$stdout" | wc -l) -eq 3 ]"
  assertStdoutContains "apple"
  assertStdoutContains "strawberry"
  assertStdoutContains "grape"
  assertStderrNull

}

testTagsPackagesForMissingArch() {
  run tags_packages_for "$(config_path)" "$data_home" \
    charlie openbsd x86_64 packages

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "pepper"
  assertStderrNull
}

testTagsPackagesForMissingAllArch() {
  run tags_packages_for "$(config_path)" "$data_home" \
    bravo bazzite x86_64 packages

  assertTrue 'function failed' "$return_status"
  assertTrue 'wrong number of results' "[ $(cat "$stdout" | wc -l) -eq 2 ]"
  assertStdoutContains "shirts"
  assertStdoutContains "shoes"
  assertStderrNull
}

testTagsPackagesForNoMathingPlatform() {
  run tags_packages_for "$(config_path)" "$data_home" \
    alfa solaris powerpc pkgsrc

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testTagsPackagesForAllOsReturnsOnEveryPlatform() {
  run tags_packages_for "$(config_path)" "$data_home" \
    "echo" macos aarch64 homeshick

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "fnichol/dot-echo"
  assertStdoutContains "fnichol/dot-echo-arm"
  assertStderrNull
}

testTagsPackagesForAllOsMergesWithOsSpecific() {
  run tags_packages_for "$(config_path)" "$data_home" \
    "echo" openbsd x86_64 homeshick

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "fnichol/dot-echo"
  assertStdoutContains "fnichol/dot-openbsd"
  assertStderrNull
}

testTagsPackagesForAllOsDoesNotPollutePmLookup() {
  run tags_packages_for "$(config_path)" "$data_home" \
    "echo" macos aarch64 homebrew

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testTagsHooksForReturnsNothingWhenNoHooksSection() {
  # delta.json has no hooks key
  run tags_packages_for "$(config_path)" "$data_home" \
    delta arch x86_64 finalize

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testTagsHooksForReturnsHooksForMatchingOs() {
  run tags_hooks_for "$(config_path)" "$data_home" \
    foxtrot arch x86_64 finalize

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apple"
  assertStdoutContains "cranberry"
  assertStderrNull
}

testTagsHooksForReturnsNothingForNonMatchingOs() {
  run tags_hooks_for "$(config_path)" "$data_home" \
    foxtrot macos x86_64 finalize

  assertTrue 'function failed' "$return_status"
  # only "all/all" bucket matches — cranberry
  assertStdoutContains "cranberry"
  assertFalse 'apple should not appear' \
    "grep -q 'apple' '$stdout'"
  assertStderrNull
}

testTagsHooksForReturnsAllOsWildcardOnEveryPlatform() {
  run tags_hooks_for "$(config_path)" "$data_home" \
    foxtrot ubuntu x86_64 finalize

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "cranberry"
  assertStderrNull
}

testTagsHooksForReturnsMultipleHooksForMatchingOs() {
  run tags_hooks_for "$(config_path)" "$data_home" \
    foxtrot cachyos x86_64 finalize

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apple"
  assertStdoutContains "banana"
  assertStdoutContains "cranberry"
  assertStderrNull
}

testTagsHooksForReturnsHooksForConfigurePhase() {
  run tags_hooks_for "$(config_path)" "$data_home" \
    foxtrot arch x86_64 configure

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "eggplant"
  assertStderrNull
}

testTagsHooksForReturnsNothingForPhaseWithNoHooks() {
  run tags_hooks_for "$(config_path)" "$data_home" \
    foxtrot arch x86_64 install

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testTagsResolveWithObjectStyleDependsOn() {
  run tags_resolve "$(config_path)" "$data_home" golf

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "alfa bravo charlie golf"
  assertStderrNull
}

testTagsPackagesForWithObjectStyleEntry() {
  run tags_packages_for "$(config_path)" "$data_home" \
    golf macos aarch64 homebrew

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "mango"
  assertStdoutContains "papaya"
  assertStderrNull
}

testTagsHooksForWithObjectStyleEntry() {
  run tags_hooks_for "$(config_path)" "$data_home" \
    golf arch x86_64 finalize

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "fig"
  assertStdoutContains "guava"
  assertStderrNull
}

testTagsListReturnsNamesFromModule() {
  writeModuleFixture "apple" "$root/tests/fixtures/data/tags"
  writeConfigFile \
    '{"modules":[{"name":"apple","url":"https://example.com/a.git"}]}'

  run tags_list_all "$(config_path)" "$data_home"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains 'alfa'
  assertStdoutContains 'bravo'
  assertStderrNull
}

testTagsListDeduplicatesAcrossModules() {
  # Both modules define "alfa" — only one entry should appear
  writeModuleFixture "first" "$root/tests/fixtures/data/tags"
  writeModuleFixture "second" "$root/tests/fixtures/data/tags"
  writeConfigFile <<-EOF
	{
	  "modules":[
	    {"name":"first","url":"https://example.com/a.git"},
	    {"name":"second","url":"https://example.com/b.git"}
	  ]
	}
	EOF

  run tags_list_all "$(config_path)" "$data_home"

  assertTrue 'function failed' "$return_status"
  # Count occurrences of "alfa" — should be exactly 1
  local count
  count="$(grep -c '^alfa$' "$stdout" || true)"
  assertEquals 'alfa should appear once' "1" "$count"
  assertStderrNull
}

testTagsPathForReturnsFirstModuleMatch() {
  writeModuleFixture "first" "$root/tests/fixtures/data/tags"
  writeModuleFixture "second" "$root/tests/fixtures/data/tags"
  writeConfigFile <<-EOF
	{
	  "modules":[
	    {"name":"first","url":"https://example.com/a.git"},
	    {"name":"second","url":"https://example.com/b.git"}
	  ]
	}
	EOF

  run tags_path_for "$(config_path)" "$data_home" "alfa"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains 'first'
  assertStdoutContains 'alfa.json'
  assertStderrNull
}

testTagsPathForFailsWhenTagMissing() {
  writeModuleFixture "alpha"
  writeConfigFile \
    '{"modules":[{"name":"alpha","url":"https://example.com/a.git"}]}'

  run tags_path_for "$(config_path)" "$data_home" "nonexistent"

  assertFalse 'should fail for missing tag' "$return_status"
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "$shunit2"
