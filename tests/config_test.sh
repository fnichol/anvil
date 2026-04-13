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

  . "${SRC:=lib/anvil/config.sh}"

  config_file="$(config_path)"
  data_home="$(modules_data_home)"

  # Copy over fixtures with an `default` module by default for tests
  writeModuleFixture \
    "default" \
    "$root/tests/fixtures/data/tags" \
    "$root/tests/fixtures/data/roles"
}

testConfigFilePath() {
  run config_path

  assertTrue 'function failed' "$return_status"
  assertStdoutContains '.config/anvil/config.json'
  assertStderrNull
}

testConfigExistsCheckNonExistent() {
  run config_exists "$tmpdir/config.json"

  assertFalse 'non-existing config file should return false' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testConfigExistsCheckExisting() {
  run config_exists "$root/tests/fixtures/config-simple.json"

  assertTrue 'existing config file should return true' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testCreateJson() {
  run config_create_json "one,two,three" "" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  cat "$stdout" | writeConfigFile

  assertJsonFromFile "$config_file" '.tags | length == 3'
  assertJsonFromFile "$config_file" '.tags | contains(["one"])'
  assertJsonFromFile "$config_file" '.tags | contains(["two"])'
  assertJsonFromFile "$config_file" '.tags | contains(["three"])'
  assertJsonFromFile "$config_file" '.skip_steps | length == 0'
  assertJsonFromFile "$config_file" '.custom_packages.add | length == 0'
  assertJsonFromFile "$config_file" '.custom_packages.remove | length == 0'
}

testCreateJsonNoTags() {
  run config_create_json "" "" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  cat "$stdout" | writeConfigFile

  assertJsonFromFile "$config_file" '.tags | length == 0'
  assertJsonFromFile "$config_file" '.skip_steps | length == 0'
  assertJsonFromFile "$config_file" '.custom_packages.add | length == 0'
  assertJsonFromFile "$config_file" '.custom_packages.remove | length == 0'
}

testCreateJsonStripsWhitespaceFromTags() {
  run config_create_json "  one,  two,   three    " "" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  cat "$stdout" | writeConfigFile

  assertJsonFromFile "$config_file" '.tags | length == 3'
  assertJsonFromFile "$config_file" '.tags | contains(["one"])'
  assertJsonFromFile "$config_file" '.tags | contains(["two"])'
  assertJsonFromFile "$config_file" '.tags | contains(["three"])'
  assertJsonFromFile "$config_file" '.skip_steps | length == 0'
  assertJsonFromFile "$config_file" '.custom_packages.add | length == 0'
  assertJsonFromFile "$config_file" '.custom_packages.remove | length == 0'
}

testCreateFile() {
  local tags expected_file config_file

  tags="one,two,three"

  run config_create_json "$tags" "" ""
  expected_file="$tmpdir/expected.json"
  cp "$stdout" "$expected_file"

  # Ensure that non-existing parent directories are created
  config_file="$tmpdir/path/to/config.json"

  run config_create "$config_file" "$tags"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull

  cmp "$expected_file" "$config_file"
  assertTrue 'config file contents differs from expected contents' "$?"
}

testCreateFileAlreadyExists() {
  mkdir -p "$(dirname "$config_file")"
  touch "$config_file"

  run config_create "$config_file" ""

  assertFalse 'function should not have succeeded' "$return_status"
  assertStdoutStripAnsiContains "file already exists"
  assertStderrNull
}

testCreateJsonWithFqdn() {
  run config_create_json "one,two" "" "host.example.com"

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  cat "$stdout" | writeConfigFile

  assertJsonFromFile "$config_file" '.fqdn == "host.example.com"'
  assertJsonFromFile "$config_file" '.tags | length == 2'
}

testCreateJsonWithoutFqdn() {
  run config_create_json "one,two" "" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  cat "$stdout" | writeConfigFile

  assertJsonFromFile "$config_file" '.fqdn == null'
  assertJsonFromFile "$config_file" '.tags | length == 2'
}

testCreateJsonFqdnAbsentWhenEmpty() {
  run config_create_json "" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  cat "$stdout" | writeConfigFile

  assertJsonFromFile "$config_file" 'has("fqdn") | not'
}

testReadFqdnSimple() {
  run config_read_fqdn "$root/tests/fixtures/config-simple.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadFqdnWithFqdnKey() {
  writeConfigFile <<-EOF
	{
	  "fqdn": "myhost.local"
	}
	EOF

  run config_read_fqdn "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "myhost.local"
  assertStderrNull
}

testReadFqdnWithNoFqdnKey() {
  writeConfigFile <<-EOF
	{}
	EOF

  run config_read_fqdn "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadFqdnWithNullFqdnKey() {
  writeConfigFile <<-EOF
	{
	  "fqdn": null
	}
	EOF

  run config_read_fqdn "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadFqdnWithNonexistentConfig() {
  run config_read_fqdn "$tmpdir/nonexistent.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadTagsSimple() {
  run config_read_tags "$root/tests/fixtures/config-simple.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "base"
  assertStdoutContains "development"
  assertStderrNull
}

testReadTagsWithTagsKey() {
  writeConfigFile <<-EOF
	{
	  "tags": ["one", "two", "three"]
	}
	EOF

  run config_read_tags "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "one"
  assertStdoutContains "two"
  assertStdoutContains "three"
  assertStderrNull
}

testReadTagsWithNoTagsKey() {
  writeConfigFile <<-EOF
	{}
	EOF

  run config_read_tags "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadTagsWithNullTagsKey() {
  writeConfigFile <<-EOF
	{
	  "tags": null
	}
	EOF

  run config_read_tags "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadTagsWithNonexistentConfig() {
  run config_read_tags "$tmpdir/nonexistent.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadRolesSimple() {
  run config_read_roles "$root/tests/fixtures/config-simple.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadRolesWithRolesKey() {
  writeConfigFile <<-EOF
	{
	  "roles": ["server", "headless"]
	}
	EOF

  run config_read_roles "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "server"
  assertStdoutContains "headless"
  assertStderrNull
}

testReadRolesWithNoRolesKey() {
  writeConfigFile <<-EOF
	{}
	EOF

  run config_read_roles "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadRolesWithNullRolesKey() {
  writeConfigFile <<-EOF
	{
	  "roles": null
	}
	EOF

  run config_read_roles "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadRolesWithNonexistentConfig() {
  run config_read_roles "$tmpdir/nonexistent.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testCreateJsonWithRoles() {
  run config_create_json "" "server,headless" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  cat "$stdout" | writeConfigFile

  assertJsonFromFile "$config_file" '.roles | length == 2'
  assertJsonFromFile "$config_file" '.roles | contains(["server"])'
  assertJsonFromFile "$config_file" '.roles | contains(["headless"])'
  assertJsonFromFile "$config_file" 'has("tags") | not'
}

testCreateJsonWithRolesAndTags() {
  run config_create_json "extra-tag" "workstation" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  cat "$stdout" | writeConfigFile

  assertJsonFromFile "$config_file" '.roles | length == 1'
  assertJsonFromFile "$config_file" '.roles | contains(["workstation"])'
  assertJsonFromFile "$config_file" '.tags | length == 1'
  assertJsonFromFile "$config_file" '.tags | contains(["extra-tag"])'
}

testCreateJsonRolesAbsentWhenEmpty() {
  run config_create_json "" "" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  cat "$stdout" | writeConfigFile

  assertJsonFromFile "$config_file" 'has("roles") | not'
}

testResolveTagsWithOnlyTags() {
  writeConfigFile <<-EOF
	{
	  "tags": ["alfa", "bravo"]
	}
	EOF

  run config_resolve_tags "$config_file" "$data_home"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "alfa"
  assertStdoutContains "bravo"
  assertStderrNull
}

testResolveTagsWithOnlyRoles() {
  writeConfigFile <<-EOF
	{
	  "roles": ["alfa"],
	  "modules":[{"name":"default","url":"https://example.com/a.git"}]
	}
	EOF

  # alfa role has tags: alfa, bravo
  run config_resolve_tags "$config_file" "$data_home"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "alfa"
  assertStdoutContains "bravo"
  assertStderrNull
}

testResolveTagsWithRolesAndTags() {
  writeConfigFile <<-EOF
	{
	  "roles": ["alfa"],
	  "tags": ["charlie"],
	  "modules":[{"name":"default","url":"https://example.com/a.git"}]
	}
	EOF

  # alfa role has tags: alfa, bravo; plus explicit tag: charlie
  run config_resolve_tags "$config_file" "$data_home"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "alfa"
  assertStdoutContains "bravo"
  assertStdoutContains "charlie"
  assertStderrNull
}

testResolveTagsWithNestedRoleDeps() {
  writeConfigFile <<-EOF
	{
	  "roles": ["charlie"],
	  "modules":[{"name":"default","url":"https://example.com/a.git"}]
	}
	EOF

  # charlie depends on bravo depends on alfa
  # alfa tags: alfa bravo; bravo tags: charlie; charlie tags: delta
  run config_resolve_tags "$config_file" "$data_home"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "alfa"
  assertStdoutContains "bravo"
  assertStdoutContains "charlie"
  assertStdoutContains "delta"
  assertStderrNull
}

testResolveTagsWithNoRolesOrTags() {
  writeConfigFile <<-EOF
	{}
	EOF

  run config_resolve_tags "$config_file" "$data_home"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testResolveTagsWithNonexistentConfig() {
  run config_resolve_tags "$tmpdir/nonexistent.json" "$data_home"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testCreateJsonIncludesEmptyModulesArray() {
  run config_create_json "" "" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  cat "$stdout" | writeConfigFile

  assertJsonFromFile "$config_file" '.modules | length == 0'
}

testReadModulesReturnsEmptyWhenNotPresent() {
  writeConfigFile '{"tags":["base"],"skip_steps":[]}'

  run config_read_modules "$(config_path)"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadModulesReturnsNamesInOrder() {
  writeConfigFile <<-EOF
	{
	  "modules":[
	    {"name":"alpha","url":"https://example.com/a.git"},
	    {"name":"beta","url":"https://example.com/b.git"}
	  ],
	  "tags":[]
	}
	EOF

  run config_read_modules "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains 'alpha'
  assertStdoutContains 'beta'
  assertStderrNull
}

testReadSkipStepsSimple() {
  run config_read_skip_steps "$root/tests/fixtures/config-simple.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "configure:hostname"
  assertStderrNull
}

testReadSkipStepsWithSkipStepsKey() {
  writeConfigFile <<-EOF
	{
	  "skip_steps": ["baking", "mowing"]
	}
	EOF

  run config_read_skip_steps "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "baking"
  assertStdoutContains "mowing"
  assertStderrNull
}

testReadSkipStepsWithNoSkipStepsKey() {
  writeConfigFile <<-EOF
	{}
	EOF

  run config_read_skip_steps "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadSkipStepsWithNullSkipStepsKey() {
  writeConfigFile <<-EOF
	{
	  "skip_steps": null
	}
	EOF

  run config_read_skip_steps "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadSkipStepsWithNonexistentConfig() {
  run config_read_skip_steps "$tmpdir/nonexistent.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomAddSimple() {
  run config_read_custom_add "$root/tests/fixtures/config-simple.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "neovim"
  assertStderrNull
}

testReadCustomAddWithCustomAddKey() {
  writeConfigFile <<-EOF
	{
	  "custom_packages": {
	    "add": ["apple", "pie"]
	  }
	}
	EOF

  run config_read_custom_add "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apple"
  assertStdoutContains "pie"
  assertStderrNull
}

testReadCustomAddWithNoAddKey() {
  writeConfigFile <<-EOF
	{
	  "custom_packages": {}
	}
	EOF

  run config_read_custom_add "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomAddWithNoCustomKey() {
  writeConfigFile <<-EOF
	{}
	EOF

  run config_read_custom_add "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomAddWithNullAddKey() {
  writeConfigFile <<-EOF
	{
	  "custom_packages": {
	    "add": null
	  }
	}
	EOF

  run config_read_custom_add "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomAddWithNullCustomKey() {
  writeConfigFile <<-EOF
	{
	  "custom_packages": null
	}
	EOF

  run config_read_custom_add "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomAddWithNonexistentConfig() {
  run config_read_custom_add "$tmpdir/nonexistent.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomRemoveSimple() {
  run config_read_custom_remove "$root/tests/fixtures/config-simple.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "badnews"
  assertStderrNull
}

testReadCustomRemoveWithCustomRemoveKey() {
  writeConfigFile <<-EOF
	{
	  "custom_packages": {
	    "remove": ["chores", "toil"]
	  }
	}
	EOF

  run config_read_custom_remove "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "chores"
  assertStdoutContains "toil"
  assertStderrNull
}

testReadCustomRemoveWithNoRemoveKey() {
  writeConfigFile <<-EOF
	{
	  "custom_packages": {}
	}
	EOF

  run config_read_custom_remove "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomRemoveWithNoCustomKey() {
  writeConfigFile <<-EOF
	{}
	EOF

  run config_read_custom_remove "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomRemoveWithNullRemoveKey() {
  writeConfigFile <<-EOF
	{
	  "custom_packages": {
	    "remove": null
	  }
	}
	EOF

  run config_read_custom_remove "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomRemoveWithNullCustomKey() {
  writeConfigFile <<-EOF
	{
	  "custom_packages": null
	}
	EOF

  run config_read_custom_remove "$config_file"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomRemoveWithNonexistentConfig() {
  run config_read_custom_remove "$tmpdir/nonexistent.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

shell_compat "$0"

. "$shunit2"
