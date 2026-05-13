<h1 align="center">
  <br/>
  Anvil
  <br/>
</h1>

<h4 align="center">
A system provisioning & configuration tool for bootstrapping &
maintaining consistent software across multiple platforms.
</h4>

|         |                                     |
| ------: | ----------------------------------- |
| License | [![License][badge-license]][github] |

<!-- CI badge will be added here once a CI provider is configured -->

<details>
<summary><strong>Table of Contents</strong></summary>

<!-- toc -->

- [Supported Platforms](#supported-platforms)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Development](#development)
- [Code of Conduct](#code-of-conduct)
- [Issues](#issues)
- [Contributing](#contributing)
- [Authors](#authors)
- [License](#license)

<!-- tocstop -->

</details>

## Overview

Anvil converges a system to a declared desired state using tags and roles to
specify which software and configuration should be present. Operations are
idempotent: Anvil always queries live system state and applies only what is
missing, making it safe to run repeatedly on new or existing systems.

## Supported Platforms

Currently, the following platforms are supported (older and newer versions may
also work):

| Platform       | Version         | Tier   |
| -------------- | --------------- | ------ |
| [Alpine Linux] | 3.23            | Tier 1 |
| [Arch Linux]   | rolling         | Tier 1 |
| [Bazzite]      | rolling         | Tier 2 |
| [CachyOS]      | rolling         | Tier 1 |
| [Debian]       | 13, rolling     | Tier 2 |
| [Fedora]       | 44              | Tier 2 |
| [FreeBSD]      | 15.0            | Tier 3 |
| [macOS]        | 26 (Tahoe)      | Tier 1 |
| [OpenBSD]      | 7.8             | Tier 1 |
| [TrueNAS]      | 25.10 (Goldeye) | Tier 2 |
| [Ubuntu]       | 26.04           | Tier 2 |

- **Tier 1**: Actively used and maintained, expected to work from test coverage,
  CI, and real world usage.
- **Tier 2**: Built with platform in mind, not used as frequently, full fidelity
  may drift over time.
- **Tier 3**: Best effort support, not actively used or tested, may accumulate
  issues.

[Alpine Linux]: https://alpinelinux.org/about/
[Arch Linux]: https://archlinux.org/
[Bazzite]: https://bazzite.gg/
[CachyOS]: https://cachyos.org/
[Debian]: https://www.debian.org/
[Fedora]: https://fedoraproject.org/
[FreeBSD]: https://www.freebsd.org/
[macOS]: https://www.apple.com/os/macos/
[OpenBSD]: https://www.openbsd.org/
[TrueNAS]: https://www.truenas.com/truenas-community-edition/
[Ubuntu]: https://ubuntu.com/

## Installation

On a system with Curl installed, download and run the install script:

```sh
curl -fsSL https://fnichol.github.io/anvil/install.sh | sh
```

Alternatively with `wget`:

```sh
wget -qO- https://fnichol.github.io/anvil/install.sh | sh
```

On a fresh OpenBSD system with `ftp`:

```sh
ftp -o - https://fnichol.github.io/anvil/install.sh | sh
```

For a full set of options, check out the help usage with:

```sh
curl -fsSL https://fnichol.github.io/anvil/install.sh | sh -s -- --help
```

## Quick Start

On first run, initialise your configuration interactively:

```sh
anvil config init
```

Then converge your system to the desired state:

```sh
anvil apply
```

## Usage

| Command                | Description                               |
| ---------------------- | ----------------------------------------- |
| `anvil apply`          | Converge system to desired state          |
| `anvil config edit`    | Edit current config in `$EDITOR`          |
| `anvil config init`    | Initialize a config file                  |
| `anvil config show`    | Show current config                       |
| `anvil module add`     | Register and fetch a module               |
| `anvil module check`   | Check if modules are up to date           |
| `anvil module install` | Fetch registered modules not yet on disk  |
| `anvil module list`    | List registered modules                   |
| `anvil module remove`  | Deregister and delete a module            |
| `anvil module show`    | Show details of a module                  |
| `anvil module update`  | Pull latest for one or all modules        |
| `anvil diff`           | Show what would change if `apply` was run |
| `anvil doctor`         | Verify system health and requirements     |
| `anvil facts`          | Show discovered system information        |
| `anvil role list`      | List available roles                      |
| `anvil role show`      | Show details of a role                    |
| `anvil self check`     | Check if a newer version is available     |
| `anvil self update`    | Update to the latest release              |
| `anvil tag list`       | List available roles                      |
| `anvil tag show`       | Show details of a role                    |
| `anvil status`         | Show current system vs. desired state     |

Run `anvil --help` or `anvil <command> --help` for full details.

## Development

Check formatting and linting:

```sh
make check
```

Run the test suite:

```sh
make test
```

> CI configuration will be added in the future.

## Code of Conduct

This project adheres to the Contributor Covenant [code of
conduct][code-of-conduct]. By participating, you are expected to uphold this
code. Please report unacceptable behavior to <fnichol@nichol.ca>.

## Issues

If you have any problems with or questions about this project, please contact us
through a [GitHub issue][issues].

## Contributing

You are invited to contribute to new features, fixes, or updates, large or
small; we are always thrilled to receive pull requests, and do our best to
process them as fast as we can.

Before you start to code, we recommend discussing your plans through a [GitHub
issue][issues], especially for more ambitious contributions. This gives other
contributors a chance to point you in the right direction, give you feedback on
your design, and help you find out if someone else is working on the same thing.

## Authors

Created and maintained by [Fletcher Nichol][fnichol] (<fnichol@nichol.ca>).

## License

Licensed under the Mozilla Public License Version 2.0 ([LICENSE.txt][license]).

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the MPL-2.0 license, shall be
licensed as above, without any additional terms or conditions.

[badge-license]: https://img.shields.io/badge/License-MPL%202.0-blue.svg
[code-of-conduct]: https://github.com/fnichol/anvil/blob/main/CODE_OF_CONDUCT.md
[fnichol]: https://github.com/fnichol
[github]: https://github.com/fnichol/anvil
[issues]: https://github.com/fnichol/anvil/issues
[license]: https://github.com/fnichol/anvil/blob/main/LICENSE.txt
