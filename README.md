# iSH-AOK Config 10.4.2

A POSIX-shell RootFS builder and running-system configuration utility designed for iSH-AOK and compatible filesystems including Devuan, Debian, Alpine, Arch Linux, Gentoo, Void Linux, Fedora and Ubuntu.

## Strict scope separation

Version 10.4 separates the application into two independent areas:

- **RootFS Builder** creates, imports, edits, validates, enters, clones and packages filesystem trees that are separate from the running system.
- **System Configuration** changes only the currently running iSH-AOK system at `/`.

System Configuration temporarily switches the configuration scope to `/`, runs the requested tool, and restores the previously selected RootFS afterward. RootFS Builder refuses to use `/` as an editable RootFS target.

## Main menu

```text
iSH-AOK Config 10.4.2

├── RootFS Builder
├── System Configuration
├── Settings
├── Search
├── About
└── Exit
```

## Streamlined RootFS Builder

```text
RootFS Builder

├── Create a New RootFS
├── Edit an Existing RootFS
├── Current Build
├── Manage RootFS Filesystems
├── More Build Options
├── Builder Help
└── Back
```

### Create a New RootFS

The guided builder asks only for the information needed to produce a filesystem:

1. Distribution
2. Architecture
3. Minimal, Standard, Developer, Server, Build, Recovery or Custom profile
4. Source
5. Destination
6. Optional RootFS identity and boot settings
7. Validation
8. Confirmation and execution

### Edit an Existing RootFS

A RootFS must be selected before configuration options are shown. The target path remains visible on the screen. Available operations include:

- Hostname, locale and timezone
- Users, passwords and sudo
- Shells and prompts inside the RootFS
- Editors inside the RootFS
- Packages and repositories inside the RootFS
- Services and boot configuration inside the RootFS
- Networking, DNS and SSH inside the RootFS
- Validation, repair and chroot access

### More Build Options

Advanced build navigation is limited to:

- Reusable build profiles
- Direct bootstrap backends
- Optional batch and multiple-target builds
- Build status, logs and recovery

Old project, workspace, dashboard and studio landing screens are not part of the normal interface.

## System Configuration

```text
System Configuration

├── Packages and Repositories
├── Services and Startup
├── Users, Passwords and Sudo
├── Shells, Prompts and Terminal
├── Editors and Editor Configuration
├── Networking, DNS and SSH
├── Storage, Mounts and Backups
├── Performance and Maintenance
├── System Health and Diagnostics
├── Advanced System Tools
└── Back
```

Every action in this menu targets the running system at `/`. A selected RootFS is displayed separately and is not modified.

## Safety and navigation

- Back and Cancel return to the previous menu.
- The build does not start until validation and final confirmation succeed.
- Destructive operations can require typed confirmation.
- The selected RootFS is restored after host-system configuration.
- RootFS editing rejects `/` to prevent accidental host modification.
- The implementation remains compatible with POSIX `sh`, dialog, whiptail and text interfaces.

## Dependency-aware installer

`install.sh` now scans the running system before copying the application. It detects the distribution, architecture and native package manager, checks the commands used by the interface and RootFS utilities, and installs only missing package groups.

Supported package managers:

- APT on Devuan, Debian and Ubuntu
- APK on Alpine
- pacman on Arch Linux
- DNF on Fedora-compatible systems
- XBPS on Void Linux
- Portage on Gentoo

Useful installer modes:

```sh
# Report missing dependencies without changing the system
sh install.sh --check

# Preview package and file operations
sh install.sh --dry-run

# Include the native builder package when available
sh install.sh --with-builders

# Install files without dependency handling
sh install.sh --skip-deps

# Allow interactive package-manager confirmation
sh install.sh --interactive
```

When `DESTDIR` is set for package creation, dependency installation is skipped automatically. Environment overrides are available through `PREFIX`, `DESTDIR`, `ISH_AOK_SKIP_DEPENDENCIES`, `ISH_AOK_ASSUME_YES` and `ISH_AOK_INSTALL_BUILDERS`.

## Validation

Run the full test suite:

```sh
sh tests/run-all.sh
```

Run menu validation:

```sh
./ish-aok-config --validate-menus
```

Version 10.4.2 validation result: **50 passed, 0 failed**.

## Install

```sh
tar -xzf ish-aok-config-project-v10.4.2.tar.gz
cd ish-aok-config-project-v10.4.2
sh install.sh
```

Run directly without installation:

```sh
./ish-aok-config
```


## v10.4.2 fixes

- The installer refreshes repository metadata, checks every mapped dependency package, and skips package names that are unavailable in the enabled repositories.
- Missing or failed optional dependency packages no longer abort installation of iSH-AOK Config.
- **System Configuration → Packages and repositories → Package repositories** now opens the host repository manager.
- Repository actions remain scoped to the running system and do not modify the selected RootFS.

## v10.5.2 — Host Software Installation

System Configuration now includes a host-only package installation center. It never modifies the selected RootFS.

### System Packages

- Quick Install: iSH-AOK Essentials
- Install additional native packages
- Curated package groups
- Remove and search packages
- Package repositories
- Refresh, upgrade, and clean operations

### Curated groups

- iSH-AOK Essentials
- Developer and build tools
- Networking tools
- Editors
- Shells and prompts
- Terminal applications
- Compression and archive tools
- Filesystem tools
- Monitoring and diagnostics
- Database clients
- Scripting languages
- RootFS builder prerequisites

Every installation checks whether packages are already installed and whether they exist in enabled repositories. Unavailable package names are shown and skipped. Editor and shell groups can launch their configuration tools after installation.

## v10.5.2 contextual installation

System Configuration menus now include installation where the software is configured. Shells can install Bash, Zsh, Fish, Starship and completions; Editors can install Nano, Vim, Neovim, Micro, Helix and Emacs; networking and development screens include curated batch installers. Missing packages are filtered through repository availability checks and all selected packages are installed in one package-manager transaction.

## v10.7.0 package-manager configuration

System Configuration now includes **Packages and repositories → Package managers and configuration**.

The package-manager hub detects and configures APT, apt-fast, Nala, APK, Pacman, DNF/YUM, XBPS, Portage, Zypper, Scoop, Homebrew, Pipx, Cargo and NPM. Compatible optional managers can be selected with Space and installed together in one batch. Native managers belonging to another distribution are shown for reference but are never installed automatically.

APT-family systems gain direct apt-fast and Nala installation/configuration. Scoop is explicitly treated as an external Windows manager and is never installed inside iSH-AOK. All package-manager actions retain the host-only scope guard and cannot modify the selected RootFS.

## v10.7.0 multi-select package actions

Every System Configuration screen containing a package collection now uses the same checklist workflow:

- Space toggles multiple packages.
- Installed packages are preselected and labelled.
- Enter opens one action menu: Install selected, Remove selected, or Update selected.
- Each action uses one native package-manager transaction and one confirmation.
- Editors, shells, terminal tools, networking, storage, archives, monitoring, languages, databases, builder prerequisites, and optional package managers share this behavior.

## v10.8.0 repository and package-source management

System Configuration now includes a distribution-aware Repository & Package Sources center. It manages native repository files, APT source lists, official Flathub setup, repository backups and health checks, plus PyPI, npm and Cargo registries. Cross-distribution repositories are never added automatically, and Scoop remains external to iSH-AOK.

## v10.10.0 repository keyring management

Repository Management now includes a distribution-aware **Install Missing Keyrings** workflow. It can multi-select and batch-install or reinstall official archive-key packages, scan APT `signed-by=` references for missing files, initialize Pacman keys, repair Alpine keys, list installed keyrings, import local APT keyring files, and refresh package indexes after repairs.

## v10.10.0 additions

- RootFS Builder preflights and installs target-distribution archive keyrings before Debian, Devuan, Ubuntu, Kali, Raspbian, Alpine, Arch, Fedora, Void, or Gentoo workflows.
- Debian-family debootstrap builds pass the detected official archive keyring with `--keyring`, including Ubuntu builds from a Devuan host.
- APT official repository components use a Space-to-select checklist and are written/refreshed as one operation.
- Repository Management includes a multi-select target-distribution keyring installer.
- Privileged configuration files are edited through a safe temporary copy, preventing Nano/Vim from dropping back to the opening menu.

## v10.11.0 target-distribution keyring bootstrap cache

RootFS builds no longer depend on foreign keyring packages being available in the host's repositories. For Ubuntu builds on Debian or Devuan, the builder downloads the official `ubuntu-keyring` package metadata and package from the selected Ubuntu archive, verifies the package SHA-256 against the archive metadata, extracts `ubuntu-archive-keyring.gpg` without installing the Ubuntu package on the host, caches it under the application state directory, and supplies it to `debootstrap` with `--keyring=`. The same cache mechanism is available for Debian and Devuan targets.

## v10.12.0 menu optimization and integrated bug audit

- Reorganized System Configuration around the most common workflows.
- Added **Diagnostics & Bug Check** with complete, route, repository, keyring, RootFS-keyring, and editor tests.
- Added automated syntax scanning for all shell entry points and modules.
- Added declarative menu callback, submenu, Back-route, and duplicate-ID validation.
- Added critical-handler checks for package checklists, repository sources, keyrings, scope isolation, and RootFS bootstrap support.
- Improved the shared editor launcher to restore terminal state and return to the originating menu after editing privileged files.
- Corrected obsolete regression tests that incorrectly required historical version numbers.

## v11.0.1 RootFS Builder Framework

The RootFS Builder now includes reusable profiles, distribution-aware package sets, an isolated download cache, build queue metadata, preflight validation, post-build validation, and reproducibility manifests. See `docs/v11/BUILDER_FRAMEWORK.md`.

## v11.1.0 Build Pipeline

Adds resumable stage checkpoints, isolated workspaces, backend abstraction, distribution metadata, lifecycle hooks, persistent history, structured logs, and dry-run pipeline validation. See `docs/v11/BUILD_PIPELINE.md`.

## v11.2.0 — Plugin SDK and Distribution SDK

This release adds a stable POSIX-shell extension layer, local plugin manager, manifest and dependency metadata, plugin/distribution generators, SDK validators, catalog format, lifecycle declarations, developer tools, and documentation. User plugins are stored outside the application core.

Command-line generators:

```sh
./sdk/new_plugin.sh example-plugin /root/example-plugin "Example Plugin" author
./sdk/distribution/new_distribution.sh mylinux /root/mylinux apk apk arm64,amd64
```

Run the SDK regression:

```sh
sh tests/v1120_plugin_sdk.sh
```

## v11.3.0 — RootFS & Workspace Edition

This release implements the portable RootFS lifecycle layer designed for iSH-AOK:

- Central RootFS library with scan, register, inspect, rename, tag, clone, export, validation, and guarded deletion.
- Workspace manager with minimal, C/C++, Rust, Python, Go, Node.js, Swift, embedded, server, and recovery templates.
- Generated workspace launchers supporting environment files, bind-mount declarations, startup commands, and selected shells.
- Portable snapshot manager using compressed archives, metadata, SHA-256 verification, restore, export, compare, and deletion.
- Cross-RootFS package operations for APT, APK, Pacman, DNF, and XBPS targets.
- RootFS comparison reports in text, Markdown, and HTML.
- Image/artifact library with checksum registration and verification.
- Validation scorecards and storage/performance reporting.
- Staged builder integration that registers successful builds and can create initial snapshots.
- Twenty-two SDK-compliant official plugins covering development tools, editors, shells, terminal utilities, networking, and container tooling.

All new implementation uses POSIX `sh` and portable text metadata suitable for Devuan, Debian, Alpine, Arch Linux, Fedora, Void, Gentoo, Ubuntu, and other filesystems used within iSH-AOK.

## v11.3.1 Software Catalog repair

- Replaced stale catalog handlers with current editor, shell, terminal, development, language, networking, and storage routes.
- Repaired the Package Groups route to use the active multi-select package group manager.
- Added category browsing and per-item configuration screens.
- Added route validation and graceful handling of unavailable catalog actions.
- Added `--software-catalog-audit` and a dedicated regression test.

## v11.3.2 Project-wide maintenance audit

- Corrected the reported application version.
- Fixed literal `\\n` rendering in the active main-menu status text.
- Added complete CLI help for v11 report and audit commands.
- Added `--version`, `--sdk-self-test`, and `--diagnostics-audit` dispatch.
- Unknown options and unexpected positional arguments now fail with exit status 2 instead of opening the interactive interface.
- Added a maintenance regression test covering version, help, dispatch, catalog integrity, and menu rendering.
