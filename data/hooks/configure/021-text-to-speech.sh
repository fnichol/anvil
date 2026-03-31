#!/usr/bin/env sh
# shellcheck disable=SC3043

# shellcheck source=/dev/null
. "$ANVIL_HOOK_SUPPORT"

configure_hook_text_to_speech() {
  case "$ANVIL_OS" in
    # See: https://wiki.archlinux.org/title/Speech_dispatcher
    arch | cachyos)
      local spd_conf_dir="$HOME/.config/speech-dispatcher"
      local spd_conf="$spd_conf_dir/speechd.conf"
      local piper_conf="$spd_conf_dir/modules/piper-tts-generic.conf"

      if [ ! -f "$spd_conf" ]; then
        info "Generating Speech Dispatcher main configuration"
        indent spd-conf \
          --create-user-conf \
          --config-basic-settings-user \
          --dont-ask
      fi

      if ! grep -q 'piper-tts-generic\.conf' "$spd_conf"; then
        local tmp_conf
        tmp_conf="$(mktemp_file)"
        cleanup_file "$tmp_conf"

        info "Customizing Speech Dispatcher with Piper"
        awk '
          /^ #AddModule "voxin"/ {
            print " AddModule \"piper-tts-generic\"         \"sd_generic\"   \"piper-tts-generic.conf\""
            next
          }
          { print }
      ' "$spd_conf" >"$tmp_conf"
        cp "$tmp_conf" "$spd_conf"
      fi

      if [ ! -f "$piper_conf" ]; then
        info "Creating Piper module configuration"
        cat <<-'EOF' >"$piper_conf"
		GenericExecuteSynth "export XDATA=\'$DATA\'; echo \"$XDATA\" | sed -z 's/\\n/ /g' | piper-tts --quiet --model \"/usr/share/piper-voices/en/en_US/hfc_male/medium/en_US-hfc_male-medium.onnx\" -f - | pw-play -"
		
		AddVoice "en-US" "male1"   "en_US-hfc_male-medium"
	EOF
      fi
      ;;
  esac
}
