#!/usr/bin/env sh
# shellcheck disable=SC3043

# Get default config file path
config_path() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/anvil"

  echo "$config_dir/config.json"
}

# Check if config file exists
config_exists() {
  local config_file="${1:-$(config_path)}"

  [ -f "$config_file" ]
}

config_create() {
  local config_file tags_str
  config_file="$1"
  tags_str="$2"

  if config_exists "$config_file"; then
    warn "Can't create new config, file already exists: $config_file"
    return 1
  fi

  mkdir -p "$(dirname "$config_file")"

  touch "$config_file"
  config_create_json "$tags_str" >"$config_file"
}

config_create_json() {
  local tags_str
  tags_str="$1"

  need_cmd jq

  jq -n --arg tags_str "$tags_str" '{
    tags: $tags_str | split(",") | map(ltrimstr(" ") | rtrimstr(" ")),
    skip_steps: [],
    custom_packages: {
      add: [],
      remove: []
    }
  }'
}

# Read tags from config
config_read_tags() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    need_cmd jq

    jq -r '.tags[]? // empty' "$config_file"
  fi
}

# Read role from config
config_read_role() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    need_cmd jq

    jq -r '.role // empty' "$config_file"
  fi
}

# Read skip steps from config
config_read_skip_steps() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    need_cmd jq

    jq -r '.skip_steps[]? // empty' "$config_file"
  fi
}

# Read custom packages to add from config
config_read_custom_add() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    need_cmd jq

    jq -r '.custom_packages.add[]? // empty' "$config_file"
  fi
}

# Read custom packages to remove from config
config_read_custom_remove() {
  local config_file="${1:-$(config_path)}"

  if config_exists "$config_file"; then
    need_cmd jq

    jq -r '.custom_packages.remove[]? // empty' "$config_file"
  fi
}
