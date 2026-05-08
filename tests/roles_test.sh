#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  commonOneTimeSetUp

  . "$SRC_ROOT/vendor/lib/libsh.full.sh"
}

setUp() {
  commonSetUp

  . "${SRC:=lib/anvil/roles.sh}"

  data_home="$(modules_data_home)"

  # Copy over fixtures with an `apple` module by default for tests
  writeModuleFixture "apple" \
    "$root/tests/fixtures/data/tags" \
    "$root/tests/fixtures/data/roles"
  writeConfigFile \
    '{"modules":[{"name":"apple","url":"https://example.com/a.git"}]}'
}

testRolesListMissingDir() {
  run roles_list "/nonexistent/path/data/roles"

  assertFalse 'function should fail for missing dir' "$return_status"
  assertStderrNull
}

testRolesResolveNoDeps() {
  run roles_resolve "$(config_path)" "$data_home" alfa

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "alfa"
  assertStderrNull
}

testRolesResolveWithDeps() {
  run roles_resolve "$(config_path)" "$data_home" charlie

  assertTrue 'function failed' "$return_status"
  # Dependencies come first: alfa, then bravo, then charlie
  assertStdoutEquals "alfa bravo charlie"
  assertStderrNull
}

testRolesResolveMultipleRoots() {
  run roles_resolve "$(config_path)" "$data_home" charlie delta alfa bravo

  assertTrue 'function failed' "$return_status"
  # delta first (no depends), then alfa next, bravo depends on alpha, and
  # charlie depends on bravo (already resolved)
  assertStdoutEquals "delta alfa bravo charlie"
  assertStderrNull
}

testRolesResolveMissingFile() {
  run roles_resolve "$(config_path)" "$data_home" nonexistent

  assertFalse 'should fail for missing role' "$return_status"
  assertStderrNull
}

testRolesTagsFor() {
  run roles_tags_for "$(config_path)" "$data_home" alfa

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "alfa"
  assertStdoutContains "bravo"
  assertStderrNull
}

testRolesTagsForMissingFile() {
  run roles_tags_for "$(config_path)" "$data_home" nonexistent

  assertFalse 'should fail for missing role' "$return_status"
  assertStderrNull
}

testRolesResolveWithObjectStyleDependsOn() {
  run roles_resolve "$(config_path)" "$data_home" echo

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "bravo alfa echo"
  assertStderrNull
}

testRolesTagsForWithObjectStyleEntry() {
  run roles_tags_for "$(config_path)" "$data_home" echo

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "alfa"
  assertStdoutContains "bravo"
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "$shunit2"
