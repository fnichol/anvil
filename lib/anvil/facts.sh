#!/usr/bin/env sh
# shellcheck disable=SC3043

# Determines the operating system name.
#
# Detects the OS by examining `uname -s` output and `/etc/os-release` on Linux
# systems. Returns normalized OS names for supported systems.
#
# * `@stdout` normalized operating system name
# * `@return 0` if successful
#
# # Supported Systems
#
# * `alpine` - Alpine Linux
# * `arch` - Arch Linux
# * `bazzite` - Bazzite Linux
# * `cachyos` - CachyOS Linux
# * `debian` - Debian Linux
# * `freebsd` - FreeBSD systems
# * `macos` - macOS/Darwin systems
# * `openbsd` - OpenBSD systems
# * `truenas` - TrueNAS SCALE (Debian-based)
# * `ubuntu` - Ubuntu Linux
# * `*-unknown` - Unrecognized systems (returns lowercased uname with suffix)
facts_os() {
  need_cmd uname
  need_cmd tr

  local system_lowercase
  system_lowercase="$(uname -s | tr '[:upper:]' '[:lower:]')"

  case "$system_lowercase" in
    darwin)
      echo "macos"
      ;;
    freebsd | openbsd)
      echo "$system_lowercase"
      ;;
    linux)
      # Attempt first to use os-release
      #
      # See:
      # https://www.freedesktop.org/software/systemd/man/latest/os-release.html
      if [ -f /etc/os-release ]; then
        local os_release_id_lowercase
        os_release_id_lowercase="$(
          # shellcheck source=/dev/null
          . /etc/os-release
          echo "${ID:-}" | tr '[:upper:]' '[:lower:]'
        )"

        # - Alpine Linux:
        # ```
        # docker run --rm -ti alpine sh -c '. /etc/os-release; echo $ID'
        # ```
        #
        # - Arch Linux:
        # ```
        # docker run --rm -ti archlinux sh -c '. /etc/os-release; echo $ID'
        # ```
        #
        # - Bazzite Linux
        # https://github.com/ublue-os/bazzite/blob/7093a006bc35bd7360627117ee4bf1b7b21d6634/build_files/image-info#L49
        #
        # - CachyOS Linux:
        #
        # ```
        # docker run --rm -ti cachyos/cachyos sh -c '. /etc/os-release; echo $ID'
        # ```
        #
        # - Debian Linux:
        #
        # ```
        # docker run --rm -ti debian sh -c '. /etc/os-release; echo $ID'
        # ```
        #
        # - Ubuntu Linux:
        # ```
        # docker run --rm -ti ubuntu sh -c '. /etc/os-release; echo $ID'
        # ```
        case "$os_release_id_lowercase" in
          alpine | arch | bazzite | cachyos | ubuntu)
            echo "$os_release_id_lowercase"
            ;;
          debian)
            # Attempt to detect TrueNAS CLI command (there aren't great ways of
            # detecting TrueNAS SCALE)
            case "$(uname -r)" in
              *+truenas)
                echo "truenas"
                ;;
              *)
                echo "$os_release_id_lowercase"
                ;;
            esac
            ;;
          *)
            echo "$os_release_id_lowercase-unknown"
            ;;
        esac
      else
        echo "$system_lowercase-unknown"
      fi
      ;;
    *)
      echo "$system_lowercase-unknown"
      ;;
  esac
}

# Determines the system architecture.
#
# Detects the CPU architecture by examining `uname -m` output. Returns
# normalized architecture names for supported systems.
#
# * `@stdout` normalized architecture name
# * `@return 0` if successful
#
# # Supported Architectures
#
# * `aarch64` - 64-bit ARM processors (ARM64, Apple Silicon)
# * `x86_64` - 64-bit x86 processors (AMD64, Intel 64)
# * `*-unknown` - Unrecognized architectures (returns uname output with suffix)
#
# # Notes
#
# On macOS systems reporting x86_64, this function checks whether the shell
# runs under Rosetta 2 emulation and returns `aarch64` for Apple Silicon Macs.
#
# Architecture detection logic derives from the Rustup shell script installer.
# See: https://github.com/rust-lang/rustup/blob/master/rustup-init.sh
facts_arch() {
  need_cmd uname

  local arch
  arch="$(uname -m)"

  if [ "$(uname -s)" = "Darwin" ] && [ "$arch" = "x86_64" ]; then
    local translated
    translated="$(sysctl -in sysctl.proc_translated 2>/dev/null || echo 0)"
    if [ "$translated" = "1" ]; then
      # If we're on a Mac and the reported architecture is x86_64, then double
      # check that the shell process isn't running under Rosetta 2 emulation,
      # otherwise we can't determine the true underlying system architecture.
      #
      # See:
      # https://indiespark.top/software/detecting-apple-silicon-shell-script/
      arch="aarch64"
    fi
  fi

  case "$arch" in
    amd64 | x86_64 | x86-64 | x64)
      echo "x86_64"
      ;;
    arm64 | aarch64 | arm64v8)
      echo "aarch64"
      ;;
    *)
      echo "$arch-unknown"
      ;;
  esac
}

# Determines the operating system version.
#
# Detects the OS version using system-specific methods: `/etc/os-release` for
# most Linux distributions, `sw_vers` for macOS, and `uname -r` for BSDs.
# Returns the version string appropriate for the detected OS.
#
# * `@stdout` operating system version string
# * `@return 0` if successful
#
# # Notes
#
# Version format varies by system (e.g., "14.5" for macOS, "24.04" for Ubuntu,
# "13.2-RELEASE" for FreeBSD).
facts_version() {
  local os
  os="$(facts_os)"

  case "$os" in
    alpine | arch | bazzite | cachyos | ubuntu)
      # Attempt first to use os-release
      #
      # See:
      # https://www.freedesktop.org/software/systemd/man/latest/os-release.html
      if [ -f /etc/os-release ]; then
        local os_release_version_id
        os_release_version_id="$(
          # shellcheck source=/dev/null
          . /etc/os-release
          echo "${VERSION_ID:-}"
        )"

        echo "$os_release_version_id"
      fi
      ;;
    debian)
      # Attempt to detect TrueNAS CLI command (there aren't great ways of
      # detecting TrueNAS SCALE)
      case "$(uname -r)" in
        *+truenas)
          cat /etc/version
          ;;
        *)
          if [ -f /etc/os-release ]; then
            local os_release_version_id
            os_release_version_id="$(
              # shellcheck source=/dev/null
              . /etc/os-release
              echo "${VERSION_ID:-}"
            )"

            echo "$os_release_version_id"
          fi
          ;;
      esac
      ;;
    freebsd | openbsd)
      uname -r
      ;;
    macos)
      sw_vers -productVersion
      ;;
    *)
      echo "version-unknown"
      ;;
  esac
}

# Determines the system hostname.
#
# Detects the hostname using system-specific methods: `/etc/hostname` for Arch
# Linux and CachyOS, or the `hostname` command for other systems.
#
# * `@stdout` system hostname
# * `@return 0` if successful
facts_hostname() {
  local os
  os="$(facts_os)"

  case "$os" in
    arch | cachyos)
      cat /etc/hostname
      ;;
    *)
      need_cmd hostname

      hostname
      ;;
  esac
}

# Outputs all system facts as a JSON object.
#
# Collects OS, architecture, version, and hostname information and formats
# them as a JSON object using `jq`.
#
# * `@stdout` JSON object containing all system facts
# * `@return 0` if successful
#
# # JSON Fields
#
# * `os` - Operating system name from `facts_os`
# * `arch` - System architecture from `facts_arch`
# * `version` - OS version from `facts_version`
# * `hostname` - System hostname from `hostname` command
# # Examples
#
# Basic usage:
#
# ```sh
# facts_json
# ```
#
# Sample output:
#
# ```json
# {
#   "os": "macos",
#   "arch": "aarch64",
#   "version": "14.5",
#   "hostname": "my-laptop"
# }
# ```
facts_json() {
  need_cmd jq

  jq -n \
    --arg os "$(facts_os)" \
    --arg arch "$(facts_arch)" \
    --arg version "$(facts_version)" \
    --arg hostname "$(hostname)" \
    '{
      os: $os,
      arch: $arch,
      version: $version,
      hostname: $hostname
    }'
}
