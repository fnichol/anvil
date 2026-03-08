#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=tests/test_helpers.sh
. "${0%/*}/test_helpers.sh"

# shellcheck source=tests/_ksh_local.sh
. "${0%/*}/_ksh_local.sh"

oneTimeSetUp() {
  . "${0%/*}/../vendor/lib/libsh.full.sh"
  . "lib/anvil/jq.sh"
  . "${SRC:=lib/anvil/config.sh}"

  commonOneTimeSetUp
}

setUp() {
  commonSetUp
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
  local config

  run config_create_json "one,two,three"

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  config="$tmpdir/config.json"
  cp "$stdout" "$config"

  assertJsonFromFile "$config" '.tags | length == 3'
  assertJsonFromFile "$config" '.tags | contains(["one"])'
  assertJsonFromFile "$config" '.tags | contains(["two"])'
  assertJsonFromFile "$config" '.tags | contains(["three"])'
  assertJsonFromFile "$config" '.skip_steps | length == 0'
  assertJsonFromFile "$config" '.custom_packages.add | length == 0'
  assertJsonFromFile "$config" '.custom_packages.remove | length == 0'
}

testCreateJsonNoTags() {
  local config

  run config_create_json ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  config="$tmpdir/config.json"
  cp "$stdout" "$config"

  assertJsonFromFile "$config" '.tags | length == 0'
  assertJsonFromFile "$config" '.skip_steps | length == 0'
  assertJsonFromFile "$config" '.custom_packages.add | length == 0'
  assertJsonFromFile "$config" '.custom_packages.remove | length == 0'
}

testCreateJsonStripsWhitespaceFromTags() {
  local config

  run config_create_json "  one,  two,   three    "

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  config="$tmpdir/config.json"
  cp "$stdout" "$config"

  assertJsonFromFile "$config" '.tags | length == 3'
  assertJsonFromFile "$config" '.tags | contains(["one"])'
  assertJsonFromFile "$config" '.tags | contains(["two"])'
  assertJsonFromFile "$config" '.tags | contains(["three"])'
  assertJsonFromFile "$config" '.skip_steps | length == 0'
  assertJsonFromFile "$config" '.custom_packages.add | length == 0'
  assertJsonFromFile "$config" '.custom_packages.remove | length == 0'
}

testCreateFile() {
  local tags expected_file config_file

  tags="one,two,three"

  run config_create_json "$tags"
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
  local config_file="$tmpdir/config.json"

  touch "$tmpdir/config.json"

  run config_create "$config_file" ""

  assertFalse 'function should not have succeeded' "$return_status"
  assertStdoutStripAnsiContains "file already exists"
  assertStderrNull
}

testCreateJsonWithFqdn() {
  local config

  run config_create_json "one,two" "host.example.com"

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  config="$tmpdir/config.json"
  cp "$stdout" "$config"

  assertJsonFromFile "$config" '.fqdn == "host.example.com"'
  assertJsonFromFile "$config" '.tags | length == 2'
}

testCreateJsonWithoutFqdn() {
  local config

  run config_create_json "one,two" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  config="$tmpdir/config.json"
  cp "$stdout" "$config"

  assertJsonFromFile "$config" '.fqdn == null'
  assertJsonFromFile "$config" '.tags | length == 2'
}

testCreateJsonFqdnAbsentWhenEmpty() {
  local config

  run config_create_json "" ""

  assertTrue 'function failed' "$return_status"
  assertStderrNull

  config="$tmpdir/config.json"
  cp "$stdout" "$config"

  assertJsonFromFile "$config" 'has("fqdn") | not'
}

testReadFqdnSimple() {
  run config_read_fqdn "$root/tests/fixtures/config-simple.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadFqdnWithFqdnKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "fqdn": "myhost.local"
	}
	EOF

  run config_read_fqdn "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "myhost.local"
  assertStderrNull
}

testReadFqdnWithNoFqdnKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{}
	EOF

  run config_read_fqdn "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadFqdnWithNullFqdnKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "fqdn": null
	}
	EOF

  run config_read_fqdn "$tmpdir/config.json"

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
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "tags": ["one", "two", "three"]
	}
	EOF

  run config_read_tags "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "one"
  assertStdoutContains "two"
  assertStdoutContains "three"
  assertStderrNull
}

testReadTagsWithNoTagsKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{}
	EOF

  run config_read_tags "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadTagsWithNullTagsKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "tags": null
	}
	EOF

  run config_read_tags "$tmpdir/config.json"

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

testReadRoleSimple() {
  run config_read_role "$root/tests/fixtures/config-simple.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadRoleWithRoleKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "role": "server"
	}
	EOF

  run config_read_role "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "server"
  assertStderrNull
}

testReadRoleWithNoRoleKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{}
	EOF

  run config_read_role "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadRoleWithNullRoleKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "role": null
	}
	EOF

  run config_read_role "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadRoleWithNonexistentConfig() {
  run config_read_role "$tmpdir/nonexistent.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadSkipStepsSimple() {
  run config_read_skip_steps "$root/tests/fixtures/config-simple.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutEquals "configure:hostname"
  assertStderrNull
}

testReadSkipStepsWithSkipStepsKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "skip_steps": ["baking", "mowing"]
	}
	EOF

  run config_read_skip_steps "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "baking"
  assertStdoutContains "mowing"
  assertStderrNull
}

testReadSkipStepsWithNoSkipStepsKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{}
	EOF

  run config_read_skip_steps "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadSkipStepsWithNullSkipStepsKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "skip_steps": null
	}
	EOF

  run config_read_skip_steps "$tmpdir/config.json"

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
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "custom_packages": {
	    "add": ["apple", "pie"]
	  }
	}
	EOF

  run config_read_custom_add "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "apple"
  assertStdoutContains "pie"
  assertStderrNull
}

testReadCustomAddWithNoAddKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "custom_packages": {}
	}
	EOF

  run config_read_custom_add "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomAddWithNoCustomKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{}
	EOF

  run config_read_custom_add "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomAddWithNullAddKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "custom_packages": {
	    "add": null
	  }
	}
	EOF

  run config_read_custom_add "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomAddWithNullCustomKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "custom_packages": null
	}
	EOF

  run config_read_custom_add "$tmpdir/config.json"

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
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "custom_packages": {
	    "remove": ["chores", "toil"]
	  }
	}
	EOF

  run config_read_custom_remove "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutContains "chores"
  assertStdoutContains "toil"
  assertStderrNull
}

testReadCustomRemoveWithNoRemoveKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "custom_packages": {}
	}
	EOF

  run config_read_custom_remove "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomRemoveWithNoCustomKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{}
	EOF

  run config_read_custom_remove "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomRemoveWithNullRemoveKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "custom_packages": {
	    "remove": null
	  }
	}
	EOF

  run config_read_custom_remove "$tmpdir/config.json"

  assertTrue 'function failed' "$return_status"
  assertStdoutNull
  assertStderrNull
}

testReadCustomRemoveWithNullCustomKey() {
  cat <<-EOF >"$tmpdir/config.json"
	{
	  "custom_packages": null
	}
	EOF

  run config_read_custom_remove "$tmpdir/config.json"

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

shell_compat "$0"

. "$shunit2"
