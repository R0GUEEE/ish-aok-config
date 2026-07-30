#!/bin/bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf -- "$tmpdir"' EXIT

failures=0
checks=0
check() {
    local description="$1"
    shift
    checks=$((checks + 1))
    if "$@"; then
        printf 'ok %d - %s\n' "$checks" "$description"
    else
        printf 'not ok %d - %s\n' "$checks" "$description"
        failures=$((failures + 1))
    fi
}

contains() { grep -Fq -- "$2" "$1"; }
not_contains() { ! grep -Fq -- "$2" "$1"; }
function_exists() { declare -F "$1" >/dev/null; }

# A caller-provided SYSTUI_TMP must never be treated as an owned directory.
sentinel="$tmpdir/do-not-delete"
mkdir -p "$sentinel"
SYSTUI_TMP="$sentinel" TMPDIR="$tmpdir" bash -c '
    . "$1"
    [ "$SYSTUI_TMP" != "$2" ]
    [ -f "$SYSTUI_TMP/.systui-owned" ]
' _ "$PROJECT_DIR/src/core/config.sh" "$sentinel"
check "pre-existing SYSTUI_TMP is not deleted" test -d "$sentinel"

SYSTUI_TMP="$tmpdir/runtime"
mkdir -p "$SYSTUI_TMP"
LOGFILE="$tmpdir/test.log"
PM=apt
INIT=systemd
export SYSTUI_TMP LOGFILE PM INIT

# shellcheck source=../src/features/rootfs.sh
source "$PROJECT_DIR/src/features/rootfs.sh"
# shellcheck source=../src/features/sysconfig.sh
source "$PROJECT_DIR/src/features/sysconfig.sh"
# shellcheck source=../src/features/health.sh
source "$PROJECT_DIR/src/features/health.sh"

check "advanced shell menu target exists" function_exists menu_shell_advanced
check "nushell manager target exists" function_exists menu_nushell
check "set default shell function exists" function_exists menu_set_default_shell
check "set default shell includes nushell (nu)" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu ksh mksh"
check "set default shell checks etc-shells" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "grep -qxF"
check "set default shell offers to add missing shell to etc-shells" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "Add to /etc/shells"
check "set default shell falls back to usermod" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "usermod -s"
check "default action in menu_shells calls new function" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "default) menu_set_default_shell"
check "obsolete advanced shell target is absent" not_contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "menu_shells_advanced"
check "all password prompts use the defined widget" not_contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "tui_pass "
check "nushell is exposed in shell config choices" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "config.nu — Nushell startup config"
check "nushell plugin manager is exposed" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "Nushell plugins —"
check "nushell plugin core catalogue defined" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "NU_PLUGINS_CORE="
check "nushell plugin popular catalogue defined" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "NU_PLUGINS_POPULAR="
check "nushell core plugins include polars" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_polars|Polars"
check "nushell core plugins include gstat" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_gstat|gstat"
check "nushell core plugins include query" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_query|Query"
check "nushell core plugins include formats" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_formats|Formats"
check "nushell popular plugins include highlight" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_highlight|"
check "nushell popular plugins include dns" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_dns|"
check "nushell popular plugins include plot" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_plot|"
check "nushell popular plugins include dbus" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_dbus|"
check "nushell popular plugins include tree" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_tree|"
check "nushell popular plugins include units" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_units|"
check "nushell popular plugins include skim" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nu_plugin_skim|"
check "nushell plugin install helper exists" function_exists nu_plugin_install_from_list
check "nushell plugin update-all helper exists" function_exists nu_plugin_update_all
check "nushell plugin cargo bin helper exists" function_exists nu_plugin_cargo_bin
check "nushell plugin display-name helper exists" function_exists nu_plugin_display_name
check "nushell plugin labels strip the nu_plugin prefix" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" 'name=${name#nu_plugin_}'
check "nushell plugin labels replace underscores with dashes" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" '${name//_/-}'
check "nushell plugin menu has core action" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" 'core    "Install core plugins'
check "nushell plugin menu has popular action" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" 'popular "Install popular third-party plugins'
check "nushell plugin menu has update action" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" 'update  "Re-register all plugins'
check "nushell multi-method install menu exists" function_exists menu_nushell_install
check "nushell github binary install helper exists" function_exists nu_github_install
check "nushell github install targets nushell releases api" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "api.github.com/repos/nushell/nushell/releases/latest"
check "nushell homebrew install method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "brew install nushell"
check "nushell cargo install method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "cargo install nu --locked"
check "nushell gemfury apt method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "apt.fury.io/nushell"

# ---- Per-package multi-method install helpers --------------------------------
check "starship install menu exists" function_exists menu_starship_install
check "starship install.sh method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "starship.rs/install.sh"
check "starship cargo method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "cargo install starship --locked"

check "zsh install menu exists" function_exists menu_zsh_install

check "fish install menu exists" function_exists menu_fish_install
check "fish PPA method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "ppa:fish-shell/release-4"

check "neovim install menu exists" function_exists menu_neovim_install
check "neovim github install helper exists" function_exists neovim_github_install
check "neovim github targets neovim releases api" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "api.github.com/repos/neovim/neovim/releases/latest"
check "neovim PPA method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "ppa:neovim-ppa/stable"

check "micro install menu exists" function_exists menu_micro_install
check "micro github install helper exists" function_exists micro_github_install
check "micro github targets zyedidia/micro releases api" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "api.github.com/repos/zyedidia/micro/releases/latest"
check "micro getmicro script method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "getmic.ro"

check "fzf install menu exists" function_exists menu_fzf_install
check "fzf github install helper exists" function_exists fzf_github_install
check "fzf github targets junegunn/fzf releases api" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "api.github.com/repos/junegunn/fzf/releases/latest"
check "fzf git-clone method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "github.com/junegunn/fzf.git"

check "docker install menu exists" function_exists menu_docker_install
check "docker convenience script method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "get.docker.com"
check "docker CE APT repo method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "download.docker.com/linux"

check "node install menu exists" function_exists menu_node_install
check "node nvm method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nvm-sh/nvm"
check "node fnm method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "fnm.vercel.app/install"
check "node nodesource method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "deb.nodesource.com/setup_lts.x"

check "ripgrep install menu exists" function_exists menu_ripgrep_install
check "ripgrep github install helper exists" function_exists rg_github_install
check "ripgrep github targets BurntSushi/ripgrep releases api" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "api.github.com/repos/BurntSushi/ripgrep/releases/latest"

check "app_page dispatches to per-package install menus" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "menu_docker_install"
check "starship menu wired into plugin_starship" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "install) menu_starship_install"
check "fzf menu wired into plugin_fzf" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "install) menu_fzf_install"
check "fish menu wired into shell hierarchy" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "install) menu_fish_install"
check "zsh menu wired into shell hierarchy" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "install) menu_zsh_install"

# Exercise the rootfs package helper without entering a real chroot.
root_target="$tmpdir/rootfs"
mkdir -p "$root_target/tmp" "$root_target/usr/sbin"
unset target || true
rootfs_chroot_exec_args() {
    [ "$1" = "$root_target" ] && [ -f "$1/tmp/systui-install-packages.sh" ]
}
check "rootfs recovery script is created inside its target" \
    rootfs_install_deb_packages "$root_target" "curl"
check "rootfs helper does not write its script to host /tmp" \
    test ! -e /tmp/systui-install-packages.sh

# The mirror probe must use each candidate argument, not a dynamically scoped
# value left by its caller.
mirror=https://bad.invalid/ubuntu
log() { :; }
curl() {
    case " $* " in
        *" https://archive.ubuntu.com/ubuntu/dists/noble/InRelease "*) return 0 ;;
        *) return 1 ;;
    esac
}
selected=$(rootfs_select_ubuntu_mirror "$mirror" amd64 noble)
check "Ubuntu mirror fallback probes the actual candidate" \
    test "$selected" = "https://archive.ubuntu.com/ubuntu"
check "Kali has only its dedicated systemd init branch" not_contains \
    "$PROJECT_DIR/src/features/rootfs.sh" "debian|ubuntu|kali)"
unset -f curl

# Generated catalogue installers must be complete and syntactically valid.
SYSTUI_AWESOME_CACHE="$tmpdir/awesome"
export SYSTUI_AWESOME_CACHE
mkdir -p "$SYSTUI_AWESOME_CACHE"
catalog="$SYSTUI_AWESOME_CACHE/catalog.tsv"
printf 'a00001\tDevelopment\tExample App\thttps://example.com\thttps://github.com/example/app\tExample\n' > "$catalog"
generate_log="$tmpdir/generate.log"
awesome_linux_generate_catalog_installers "$catalog" >"$generate_log" 2>&1
installer="$SYSTUI_AWESOME_CACHE/installers/example-app-install.sh"
check "catalogue installer generation has no expansion error" not_contains "$generate_log" "bad substitution"
check "catalogue installer includes its command dispatcher" contains "$installer" 'method=${1:-auto}'
check "catalogue installer passes POSIX shell syntax" sh -n "$installer"

# Project-specific GitHub installers must defer translated dependency variables
# until the generated script runs on the target distribution.
fake_source="$tmpdir/fake-github-source"
mkdir -p "$fake_source"
: > "$fake_source/CMakeLists.txt"
awesome_linux_github_clone() { return 0; }
awesome_linux_source_dir() { printf '%s\n' "$fake_source"; }
tui_msg() { return 0; }
github_installer=$(awesome_linux_generate_github_installer \
    "GitHub Example" "https://github.com/example/app")
check "GitHub installer preserves APK dependency expansion" contains \
    "$github_installer" 'apk add --no-cache $apk_deps'
check "GitHub installer preserves Pacman dependency expansion" contains \
    "$github_installer" 'pacman -S --needed --noconfirm $pacman_deps'
check "GitHub installer preserves DNF dependency expansion" contains \
    "$github_installer" 'dnf install -y --setopt=install_weak_deps=False $dnf_deps'
check "GitHub installer passes POSIX shell syntax" sh -n "$github_installer"

# Healthy package/service commands may print routine status text but should
# still produce the explicit clean markers used by the dashboard.
dpkg() { return 0; }
apt-get() { printf 'Reading package lists...\nBuilding dependency tree...\n'; return 0; }
systemctl() { return 0; }
package_report=$(health_tmp test-packages)
service_report=$(health_tmp test-services)
health_package_issues "$package_report"
health_service_issues "$service_report"
check "healthy APT state is reported as clean" contains "$package_report" "No package integrity problems detected."
check "healthy systemd state is reported as clean" contains "$service_report" "No failed or crashed services detected."
case "$(health_tmp private)" in "$SYSTUI_TMP"/*) private_ok=1 ;; *) private_ok=0 ;; esac
check "health reports stay in the private workspace" test "$private_ok" -eq 1

# ---- Per-manager install menus ---------------------------------------------
check "menu_brew_install exists"        function_exists menu_brew_install
check "menu_nix_install exists"         function_exists menu_nix_install
check "menu_yay_install exists"         function_exists menu_yay_install
check "menu_paru_install exists"        function_exists menu_paru_install
check "menu_cargo_install exists"       function_exists menu_cargo_install
check "menu_npm_install exists"         function_exists menu_npm_install
check "menu_pnpm_install exists"        function_exists menu_pnpm_install
check "menu_yarn_install exists"        function_exists menu_yarn_install
check "menu_gem_install exists"         function_exists menu_gem_install
check "menu_composer_install exists"    function_exists menu_composer_install
check "menu_go_install exists"          function_exists menu_go_install
check "menu_pipx_install exists"        function_exists menu_pipx_install
check "menu_pip_install exists"         function_exists menu_pip_install
check "menu_flatpak_install exists"     function_exists menu_flatpak_install
check "menu_snap_install exists"        function_exists menu_snap_install
# Root-compatible Homebrew installer tests
check "menu_brew_install exists"               function_exists menu_brew_install
check "brew root installer helper exists"      function_exists brew_root_compat_script
check "brew root env helper exists"            function_exists brew_root_compat_env_file
check "brew root installer moved to share/"    test -f "$PROJECT_DIR/share/homebrew/install-homebrew-root.sh"
check "brew sysconfig uses shared installer path" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" 'share/homebrew/install-homebrew-root.sh'
check "brew root install checks root UID"      contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "Root privileges are required"
check "brew installer defines LD_PRELOAD shim" contains \
    "$PROJECT_DIR/share/homebrew/install-homebrew-root.sh" "libhomebrew_fakeuid.so"
check "brew installer defines linuxbrew prefix" contains \
    "$PROJECT_DIR/share/homebrew/install-homebrew-root.sh" "/home/linuxbrew/.linuxbrew"
check "brew installer defines permanent env dir" contains \
    "$PROJECT_DIR/share/homebrew/install-homebrew-root.sh" 'readonly ROOT_ENV_DIR="/etc/systui"'
check "brew installer defines permanent env file variable" contains \
    "$PROJECT_DIR/share/homebrew/install-homebrew-root.sh" 'readonly ROOT_ENV_FILE="${ROOT_ENV_DIR}/homebrew.env"'
check "brew advanced config targets permanent env file when active" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "/etc/systui/homebrew.env"
check "brew installer is no longer embedded in sysconfig" not_contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "Root-managed Homebrew installer for Debian arm64 on iSH-AOK."
check "brew pm install option removed" not_contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" 'Package manager (${PM} install brew)'
check "nix determinate installer URL present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "install.determinate.systems/nix"
check "nix official multi-user install present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nixos.org/nix/install"
check "yay AUR git clone present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "aur.archlinux.org/yay.git"
check "paru AUR git clone present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "aur.archlinux.org/paru.git"
check "cargo rustup install script present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "sh.rustup.rs"
check "npm nvm install script present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "nvm-sh/nvm"
check "npm fnm install script present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "fnm.vercel.app/install"
check "npm nodesource APT setup present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "deb.nodesource.com"
check "pnpm official install script present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "get.pnpm.io/install.sh"
check "yarn corepack enable present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "corepack enable"
check "gem rbenv install present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "rbenv.org/install.sh"
check "gem rvm install present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "get.rvm.io"
check "composer official installer present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "getcomposer.org/installer"
check "go official tarball URL present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "go.dev/dl"
check "pip get-pip.py URL present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "bootstrap.pypa.io/get-pip.py"
check "pip ensurepip method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "ensurepip --upgrade"
check "pipx pip install method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "pip3 install --user pipx"
check "flatpak Flathub remote add present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "dl.flathub.org/repo/flathub.flatpakrepo"
check "snap enable service method present" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "snapd.service"

# menu_cfg_cli_manager accepts 5th install-fn argument
check "menu_cfg_cli_manager install_fn param" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" 'install_fn='
check "menu_cfg_cli_manager calls install_fn" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" '"$install_fn"'

# Wiring: install functions passed into menu_package_managers dispatch
check "brew wired with menu_brew_install" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "menu_brew_install"
check "nix wired with menu_nix_install" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "menu_nix_install"
check "cargo wired with menu_cargo_install" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "menu_cargo_install"
check "npm wired with menu_npm_install" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "menu_npm_install"
check "yay wired with menu_yay_install" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "menu_yay_install"
check "paru wired with menu_paru_install" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "menu_paru_install"
check "flatpak guard uses menu_flatpak_install" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "menu_flatpak_install"
check "snap guard uses menu_snap_install" contains \
    "$PROJECT_DIR/src/features/sysconfig.sh" "menu_snap_install"

# ---- Popular repositories expansions --------------------------------------
# APT_POPULAR new entries
check "APT_POPULAR has kubernetes repo"      contains "$PROJECT_DIR/src/features/sysconfig.sh" "pkgs.k8s.io/core:/stable:/v1.32/deb"
check "APT_POPULAR has github-cli repo"      contains "$PROJECT_DIR/src/features/sysconfig.sh" "cli.github.com/packages/githubcli-archive-keyring.gpg"
check "APT_POPULAR has brave repo"           contains "$PROJECT_DIR/src/features/sysconfig.sh" "brave-browser-apt-release.s3.brave.com"
check "APT_POPULAR has sublime-text repo"    contains "$PROJECT_DIR/src/features/sysconfig.sh" "download.sublimetext.com"
check "APT_POPULAR has signal repo"          contains "$PROJECT_DIR/src/features/sysconfig.sh" "updates.signal.org/desktop/apt"
check "APT_POPULAR has spotify repo"         contains "$PROJECT_DIR/src/features/sysconfig.sh" "repository.spotify.com"
check "APT_POPULAR has influxdb repo"        contains "$PROJECT_DIR/src/features/sysconfig.sh" "repos.influxdata.com/stable"
check "APT_POPULAR has elastic repo"         contains "$PROJECT_DIR/src/features/sysconfig.sh" "artifacts.elastic.co/packages/8.x/apt"
check "APT_POPULAR has cloudflared repo"     contains "$PROJECT_DIR/src/features/sysconfig.sh" "pkg.cloudflare.com/cloudflared"
check "APT_POPULAR has virtualbox repo"      contains "$PROJECT_DIR/src/features/sysconfig.sh" "download.virtualbox.org/virtualbox/debian"

# DNF new entries
check "DNF popular has kubernetes"           contains "$PROJECT_DIR/src/features/sysconfig.sh" "pkgs.k8s.io/core:/stable:/v1.32/rpm"
check "DNF popular has github-cli"           contains "$PROJECT_DIR/src/features/sysconfig.sh" "cli.github.com/packages/rpm/gh-cli.repo"
check "DNF popular has grafana"              contains "$PROJECT_DIR/src/features/sysconfig.sh" "rpm.grafana.com"
check "DNF popular has hashicorp"            contains "$PROJECT_DIR/src/features/sysconfig.sh" "rpm.releases.hashicorp.com"
check "DNF popular has brave"                contains "$PROJECT_DIR/src/features/sysconfig.sh" "brave-browser-rpm-release.s3.brave.com"
check "DNF popular has influxdb"             contains "$PROJECT_DIR/src/features/sysconfig.sh" "repos.influxdata.com/rhel"
check "DNF popular has elastic"              contains "$PROJECT_DIR/src/features/sysconfig.sh" "artifacts.elastic.co/packages/8.x/yum"
check "DNF popular has postgres"             contains "$PROJECT_DIR/src/features/sysconfig.sh" "download.postgresql.org/pub/repos/yum"

# Pacman new entries
check "Pacman popular has blackarch"         contains "$PROJECT_DIR/src/features/sysconfig.sh" "blackarch.org/strap.sh"
check "Pacman popular has cachyos"           contains "$PROJECT_DIR/src/features/sysconfig.sh" "mirror.cachyos.org"
check "Pacman popular has endeavouros"       contains "$PROJECT_DIR/src/features/sysconfig.sh" "mirror.endeavouros.com"

# zypper case added
check "zypper popular repos case exists"     contains "$PROJECT_DIR/src/features/sysconfig.sh" "zypper)"
check "zypper packman repo present"          contains "$PROJECT_DIR/src/features/sysconfig.sh" "ftp.gwdg.de/pub/linux/misc/packman"
check "zypper kubernetes repo present"       contains "$PROJECT_DIR/src/features/sysconfig.sh" "pkgs.k8s.io/core:/stable:/v1.32/rpm"
check "zypper grafana repo present"          contains "$PROJECT_DIR/src/features/sysconfig.sh" "rpm.grafana.com"

# APK edge repos
check "APK edge-main option present"         contains "$PROJECT_DIR/src/features/sysconfig.sh" "edge-main"
check "APK edge-community option present"    contains "$PROJECT_DIR/src/features/sysconfig.sh" "edge-community"

printf '1..%d\n' "$checks"
[ "$failures" -eq 0 ]
