# systui — Modular Linux System Administration TUI 

## Overview

systui is a comprehensive Linux system administration tool with:
- **Modular architecture** — Clean separation of concerns
- **Dialog-based TUI** — Terminal UI for easy navigation
- **Multi-distro support** — Alpine, Arch, Debian, Devuan
- **Easy installation** — Single `install.sh` script
- **Extensible design** — Add features by creating modules

## Quick Start

### Installation

```bash
# Clone or download the project
git clone https://github.com/... systui
cd systui

# Run installation (requires root)
sudo ./install.sh

# Use systui
sudo systui
```

### First Run

```bash
sudo systui
→ Main Menu
→ Ultimate Provision
→ Configure (set timezone, username, hostname, sudo preference)
→ Run (provisioning starts automatically)
→ Re-login to activate changes
```

## Project Structure

```
systui-project/
│
├── install.sh                # Installation script (dependencies + setup)
├── README.md                 # This file
│
├── src/                      # Source code (modules)
│   ├── core/                 # Core utilities and framework
│   │   ├── config.sh         # System detection and config
│   │   ├── tui-widgets.sh    # TUI widget functions
│   │   └── common.sh         # Common utilities & package mapping
│   │
│   ├── provision/            # Provisioning functions (one per distro)
│   │   ├── alpine.sh         # Alpine 3.23+ (OpenRC)
│   │   ├── arch.sh           # Arch Linux (systemd)
│   │   ├── debian.sh         # Debian 12+ (systemd)
│   │   └── devuan.sh         # Devuan 6+ (sysvinit)
│   │
│   └── features/             # Feature modules (optional/future)
│       ├── shells.sh         # Shell management
│       ├── repos.sh          # Repository management
│       └── rootfs.sh         # Rootfs building
│
├── share/                    # Non-code resources
│   └── config/               # Configuration templates
│       └── shell-niceties.sh # Shell environment template
│
├── bin/                      # Executable wrappers (generated)
│   └── systui                # Main executable
│
├── docs/                     # Documentation
│   ├── ARCHITECTURE.md       # System design
│   ├── GETTING_STARTED.md    # User guide
│   ├── DEVELOPER_GUIDE.md    # Developer documentation
│   └── API.md                # Module API reference
│
└── tests/                    # Test suite (optional)
    └── test-*.sh             # Test files
```

## Module System

### Core Modules

#### `src/core/config.sh`
- System detection (PM, init, distro)
- Logging and error handling
- Configuration management

**Key Functions:**
```bash
detect_pm()           # Detect package manager
detect_init()         # Detect init system
detect_distro()       # Detect Linux distribution
require_root()        # Ensure root access
log <message>         # Log to /tmp/systui.log
warn <message>        # Log warning
die <message>         # Fatal error and exit
```

#### `src/core/tui-widgets.sh`
- Dialog wrapper functions
- TUI components (menu, input, checkbox, etc.)
- Command execution with output

**Key Functions:**
```bash
tui_msg <title> <message>              # Message dialog
tui_yesno <title> <question>           # Yes/no dialog
tui_input <title> <prompt> [default]   # Input dialog
tui_menu <title> <text> <tag> <desc>   # Menu selection
tui_check <title> <text> <tag> <desc>  # Checkbox list
tui_radio <title> <text> <tag> <desc>  # Radio list
tui_text <title> <file>                # Text viewer
run_cmd <description> <cmd...>         # Run command with output
```

#### `src/core/common.sh`
- Package mapping (Debian → Alpine/Arch/Fedora/Void)
- Package manager operations
- Common utilities

**Key Functions:**
```bash
map_packages <family> <pkgs...>  # Map package names
pm_install <pkgs...>            # Install packages
pm_remove <pkgs...>             # Remove packages
pm_update                        # Update package lists
cmd_exists <command>            # Check if command exists
```

### Provisioning Modules

Each distro has its own provisioning module:

#### `src/provision/alpine.sh`
- Alpine 3.23+ with OpenRC
- Installs 60+ packages
- Configures services (sshd, syslog-ng, cronie, chronyd)

#### `src/provision/arch.sh`
- Arch Linux with systemd
- Special handling: uid-501 repair, /dev/fd symlinks
- Handles alarm user rename

#### `src/provision/debian.sh`
- Debian 12+ (bookworm, trixie, sid)
- APT-based provisioning
- Services: ssh, rsyslog, cron, chrony

#### `src/provision/devuan.sh`
- Devuan 6+ (Excalibur)
- Legacy sysvinit support
- Services: sshd, rsyslog, cron, chrony

**Provisioning Function Signature:**
```bash
provision_alpine <timezone> <username> <hostname> <nopass_flag>
provision_arch <timezone> <username> <hostname> <nopass_flag>
provision_debian <timezone> <username> <hostname> <nopass_flag>
provision_devuan <timezone> <username> <hostname> <nopass_flag>
```

Each function:
1. Installs 60+ packages
2. Sets timezone and locale
3. Creates user account
4. Configures sudo access
5. Enables services
6. Creates MOTD and shell environment

## Installation Details

### What `install.sh` Does

1. **Detects package manager** (apt, apk, pacman, dnf)
2. **Installs dependencies:**
   - bash
   - dialog
   - Standard utilities (grep, sed, awk, etc.)
   - Network tools (openssh, curl, wget)
   - Essential files (ca-certificates, tzdata)

3. **Installs project files** to `/usr/local/lib/systui/`
4. **Creates executable** at `/usr/local/bin/systui`
5. **Creates man page** for documentation
6. **Verifies installation**

### Dependencies

**Minimum required:**
- bash 4.0+
- dialog
- grep, sed, awk, cut, tr (standard utilities)
- openssl (for cryptography)
- curl or wget (for network operations)

**Optional:**
- man-db (for documentation)
- git (for cloning)
- tzdata (for timezone support)

## Usage Examples

### Basic Usage

```bash
# Run systui
sudo systui

# Navigate with arrow keys, Enter to select
Main Menu
  → Ultimate Provision
    → Review (see what gets installed)
    → Configure (set options)
    → Run (start provisioning)
    → Info (detailed reference)
```

### Provisioning a Fresh System

```bash
# On Alpine 3.23+
sudo systui
→ Ultimate Provision → Configure
→ Timezone: UTC
→ Username: admin
→ Hostname: myserver
→ Sudo: password required (or passwordless)
→ Run

# Provisioning starts automatically
# Takes 5-15 minutes depending on internet speed
# Services automatically enabled and started
```

### Manual Provisioning (Without TUI)

For automation/CI-CD:

```bash
# Direct provision script calls (with TUI built-in)
sudo bash /usr/local/lib/systui/src/provision/debian.sh

# Pre-set environment variables for non-interactive mode
TZ_NAME=UTC \
TARGET_USER=admin \
NEW_HOSTNAME=prod-server \
SUDO_NOPASSWD=0 \
sudo bash /usr/local/lib/systui/src/provision/debian.sh
```

## Configuration

### User Configuration

Configuration stored in `~/.systui/config`:

```bash
# Set timezone preference
systui-config-set "timezone" "America/New_York"

# Set preferred shell
systui-config-set "shell" "bash"
```

### System-Wide Configuration

Location: `/etc/systui/config`

```bash
# Default distro preferences
default_timezone=America/Los_Angeles
enable_services=true
install_docs=true
```

## Adding Features

### Create a New Feature Module

1. Create file: `src/features/myfeature.sh`
2. Define functions:

```bash
#!/bin/bash
# systui — My Feature

menu_myfeature() {
    local choice
    choice=$(tui_menu "My Feature" "Description:" \
        option1 "First option" \
        option2 "Second option" \
        back    "Back") || return
    
    case "$choice" in
        option1) do_something_1 ;;
        option2) do_something_2 ;;
        back)    return ;;
    esac
}

export -f menu_myfeature
```

3. Add to main menu in `bin/systui`:

```bash
. "$LIBDIR/src/features/myfeature.sh"

# In main_menu():
myfeature) menu_myfeature ;;
```

### Adding a New Distro

1. Create: `src/provision/newdistro.sh`
2. Define: `provision_newdistro()`
3. Update `detect_distro()` in `src/core/config.sh`
4. Source in `bin/systui`

## Troubleshooting

### "Command not found: dialog"

```bash
# Install dialog
sudo apt install dialog        # Debian
sudo apk add dialog            # Alpine
sudo pacman -S dialog          # Arch
sudo dnf install dialog        # Fedora
```

### "Must run as root"

```bash
# Run with sudo
sudo systui
```

### "Package not found"

- Check `/tmp/systui.log` for details
- Package mapping in `src/core/common.sh` may need updates
- Some packages have distro-specific names

### Provisioning failed

1. Check log file: `cat /tmp/systui.log`
2. Check internet connectivity
3. Verify distro is supported
4. Try again (scripts are idempotent)

## Development

### Project Structure Rationale

- **Modular design** → Easy to test, extend, maintain
- **Function-based** → No class complexity, pure bash
- **Logging everywhere** → Debug issues easily
- **Consistent patterns** → Similar code style throughout

### Code Style

- Use `#!/bin/bash` (bash-specific features OK)
- Export functions: `export -f function_name`
- Log important operations: `log "message"`
- Validate input in functions
- Use `set -e` to catch errors
- Comment complex logic

### Testing

```bash
# Syntax check
bash -n src/core/config.sh
bash -n src/core/tui-widgets.sh
bash -n src/core/common.sh

# Function test
bash src/core/config.sh
detect_pm
echo $PM

# Full test
sudo ./install.sh
sudo systui
# Test menu navigation and features
```

## Performance

- **Startup:** < 1 second
- **Menu navigation:** Instant
- **Provisioning:** 5-15 minutes (depends on distro and internet)
- **Memory:** < 10 MB
- **Disk:** < 5 MB (project files)

## Supported Distributions

| Distro | Version | Init | PM | Status |
|--------|---------|------|----|----|
| Alpine | 3.23+ | OpenRC | apk | ✓ Supported |
| Arch | Current | systemd | pacman | ✓ Supported |
| Debian | 12+ | systemd | apt | ✓ Supported |
| Devuan | 6+ | sysvinit | apt | ✓ Supported |
| Ubuntu | 22.04+ | systemd | apt | ✓ Compatible |
| Fedora | 38+ | systemd | dnf | ✓ Partial |

## Known Limitations

1. **Feature modules not yet implemented** — Shells, repos, rootfs planned
2. **Offline provisioning** — Requires internet for package downloads
3. **Non-interactive provisioning** — TUI always shown (but scriptable via env vars)
4. **Limited customization** — Edit scripts for fine-grained control

## Future Enhancements

- [ ] Feature modules (shells, repos, rootfs)
- [ ] Fedora/RHEL/CentOS support
- [ ] Configuration file support
- [ ] Package version pinning
- [ ] Automated testing suite
- [ ] Plugin system
- [ ] Cloud-init integration
- [ ] Backup/restore functionality

## License

Free and open for use, modification, and distribution.

## Support

- **Documentation:** See `/usr/local/lib/systui/docs/`
- **Log file:** `/tmp/systui.log`
- **Man page:** `man systui`

## Version History

- **1.0.0** (2026-07-29) — Initial release
  - Modular architecture
  - Multi-distro provisioning
  - TUI framework
  - Alpine, Arch, Debian, Devuan support

---

**Happy provisioning!** 🚀

For detailed architecture, see `docs/ARCHITECTURE.md`  
For developers, see `docs/DEVELOPER_GUIDE.md`

## Expanded Software Catalogue

The package catalogue now includes:

- 17 software categories covering terminal tools, development, networking,
  security, monitoring, servers, containers, backups, multimedia and more.
- Curated one-click collections for iSH-AOK essentials, development stacks,
  servers, networking, security and backup environments.
- Bulk package-list export/import and bulk removal.
- Package health checks, orphan detection, cache cleanup and integrity checks.
- Rich package pages with install, remove, reinstall, metadata, installed-file,
  version-hold and package-integrity actions.
- Package-name translation for APT, APK, Pacman and DNF environments.

## Expanded Ultimate Provision Configuration

The Ultimate Provision menu now includes grouped configuration for:

- Identity, hostname, timezone, locale, and sudo policy
- Default shell and editor
- Selectable package profiles: core, development, terminal, networking,
  server, security, multimedia, backup, and containers
- Service startup selection for SSH, cron, time synchronization, logging,
  mDNS, and web services
- SSH port, root-login policy, and password-authentication policy
- Optional firewall and conservative filesystem/SSH hardening
- iSH-AOK compatibility, balanced, and performance profiles
- Optional 512 MiB swap file and post-install package cleanup
- Full review screen before provisioning and reset-to-default support

The compatibility profile is recommended for constrained iSH-AOK filesystems.
Kernel-dependent features are skipped safely when unavailable.


## Expanded rootfs and package management

- Repository-backed, SPACE-selectable release discovery with offline fallbacks.
- Expanded minimal, workstation, development, server, web, and security presets.
- Profile-based custom package installation and additional individual packages.
- In-rootfs locale, timezone, shell, editor, SSH, services, package update/upgrade, cleanup, machine-id, and mount-helper configuration.
- Rootfs management exposes the same post-build configuration controls.
- `tar.gz` is the default build and management compression format.
- System Configuration → Packages begins with Package Managers, followed by Repositories and Catalogue.
- Package-manager configuration covers APT, apt-fast, Nala, pip, pipx, Flatpak, Snap, Cargo, npm, pnpm, and Yarn.
- Additional iSH-AOK, memory, writeback, tmpfs, and DNS-cache performance controls.
- `install.sh` installs rootfs-building, archive, keyring, QEMU, and scripting prerequisites where packaged.
- Menu cancellation paths return to their parent menu instead of propagating a fatal status.

## Additional rootfs distributions

Kali Linux, openSUSE Leap, openSUSE Tumbleweed, and Gentoo stage3 are available from the Rootfs Builder.

## Distribution Provision Templates

Ultimate Provision now includes two distribution-oriented tools:

- **List Distribution Provision Templates** shows built-in and generated templates for Alpine, Arch Linux, Debian, Devuan, Ubuntu, Kali, Fedora, Void, openSUSE Leap, openSUSE Tumbleweed, and Gentoo.
- **Generate Provision Scripts** uses a SPACE-to-select checklist and creates standalone scripts for selected distributions when a template is missing. Existing generated scripts require explicit overwrite confirmation.

Generated scripts are stored in `share/generated-provision/` inside the systui installation and support minimal, standard, developer, and server package profiles through the `INSTALL_PROFILE` environment variable.


## System Health

The main-menu **System Health** section replaces the former log viewer and provides:

- Quick health dashboard
- Full exportable health reports
- Package integrity and dependency checks
- Storage, filesystem, inode, and mount checks
- Failed/crashed service detection
- Network, route, resolver, and listening-port checks
- Security configuration audit
- CPU, memory, process, zombie, and kernel-warning checks
- Conservative package repair, cleanup, SSH validation, and fstab validation

The internal operation log remains available at `/tmp/systui.log` for command diagnostics.

## Package and shell menu organization

System Configuration > Packages now contains Package Managers, Repos, Catalogue, Packages, and Advanced. Native install, remove, search, information, installed-package listing, hold, update, and cleanup actions are grouped under the Packages submenu.

APT repository management includes both `/etc/apt/sources.list` and `/etc/apt/sources.list.d/`. The signing-key menu can install available Debian, Ubuntu, Devuan, and Kali archive keyrings using a SPACE-to-select checklist.

System Configuration > Shells separates Managers from Plugins. Each Bash, Zsh, and Fish manager includes installation, removal, and its framework/plugin-manager configuration. Cross-shell plugins include Starship, fzf, completion packages, zoxide, Atuin, direnv, Carapace, syntax highlighting, and autosuggestions.

## Terminal file managers

`System Configuration > File Managers` manages terminal file managers and their user configuration:

- lf
- tere
- Yazi
- Ranger
- nnn
- Vifm
- Broot
- xplr

Each entry supports installation/removal, a recommended starter configuration, direct configuration editing, launching, and a GitHub-backed add-on manager. Add-ons are installed per user under the applicable `~/.config` directory; custom Git repositories are also supported.

### Adaptive provision scripts
Provision templates now run a system preflight before making changes. The preflight reads
`os-release`, verifies the target distribution family and package manager, detects the init
system, architecture, container/chroot state, and uses the appropriate service adapter.
Standalone scripts generated by Ultimate Provision include the same checks and refuse to run
against an incompatible distribution.

### Shell plugin configuration managers
System Configuration > Shells > Plugins now opens a per-user manager for each plugin. Starship, fzf, completions, zoxide, Atuin, direnv, Carapace, Zsh syntax highlighting, and Zsh autosuggestions include install/remove actions, shell integration, editable configuration, status inspection, and cleanup controls.

## Updating

From a Git checkout:

```bash
sudo ./update.sh
```

After installation, the same updater is available globally:

```bash
sudo systui-update
```

The updater fetches the current branch from `origin`, backs up and stashes local source changes, fast-forwards to the latest revision, and reruns `install.sh`. Use `--no-deps` to skip package dependency installation or `--force` to reset the source checkout after creating a backup.

## RootFS additional package catalogue

The RootFS Builder now opens a categorized package catalogue after preset selection. It supports space-to-select package lists, reusable rescue/developer/server/network/container/diagnostic presets, catalogue search, manual native package names, selection review, and de-duplication. Canonical package names are translated through the existing Alpine, Arch, Fedora, and Void package maps where available.

### Shell configuration and aliases

`System Configuration → Shells` includes:

- **Shell config files** — automatically populated targets for `.bashrc`, `.zshrc`, Fish `config.fish`, `.profile`, `.bash_profile`, `.zprofile`, and `.inputrc`. Common settings can be selected with SPACE and written into a removable systui-managed block. The tool also supports custom entries, backups, direct editing, viewing, and syntax validation.
- **Alias manager** — installs aliases from a catalog, adds or replaces custom aliases, removes aliases, imports existing alias definitions, validates syntax, and generates Fish-compatible aliases. Managed aliases are stored under `~/.config/systui/` and sourced from supported shell files.

