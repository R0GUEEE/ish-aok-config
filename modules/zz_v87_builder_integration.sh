#!/bin/sh

V87_PROFILE_DIR=${V87_PROFILE_DIR:-${AOK_PROFILE_DIR:-$STATE_DIR/aok-profiles}}
V87_BUILD_PROFILE=${V87_BUILD_PROFILE:-$V87_PROFILE_DIR/build.profile}
mkdir -p "$V87_PROFILE_DIR" 2>/dev/null || true

v87_profile_get(){ f=${1:-$V87_BUILD_PROFILE}; k=$2; sed -n "s/^$k=//p" "$f" 2>/dev/null | tail -n 1; }
v87_profile_set(){ f=$1; k=$2; v=$3; mkdir -p "$(dirname "$f")"; t="$f.tmp.$$"; { grep -v "^$k=" "$f" 2>/dev/null || true; printf '%s=%s\n' "$k" "$v"; } >"$t" && mv "$t" "$f"; }
v87_profile_defaults(){
  [ -f "$V87_BUILD_PROFILE" ] && return 0
  cat >"$V87_BUILD_PROFILE" <<'EOF_PROFILE'
PROFILE_NAME=default
DISTRO=devuan
RELEASE=excalibur
ARCH=arm64
DEST=/AOK/roots/Devuan-excalibur-arm64
MIRROR=
BOOTSTRAP=debootstrap
VARIANT=minbase
PACKAGES=ca-certificates curl wget bash bash-completion nano openssh-client openssh-server sudo dialog tzdata locales
INIT=sysvinit
HOSTNAME=ish-aok
USER_NAME=user
SHELL_PATH=/bin/bash
LOCALE=C.UTF-8
TIMEZONE=UTC
ENABLE_SSH=yes
ENABLE_SUDO=yes
ENABLE_NETWORK=yes
COPY_DNS=yes
RUN_SECOND_STAGE=yes
REGISTER_ROOTFS=yes
CREATE_PROJECT=no
POST_WORKFLOW=health_audit
COMPRESSION=zstd
EOF_PROFILE
}

v87_choice_state(){ [ "$1" = "$2" ] && printf on || printf off; }
v87_yes_state(){ [ "$1" = yes ] && printf on || printf off; }

v87_profile_choose_distro(){
  cur=$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO); [ -n "$cur" ] || cur=devuan
  d=$(ui_radiolist 'Build profile: Distribution' 'Select the target distribution.' \
    devuan 'Devuan (SysVinit-first)' "$(v87_choice_state "$cur" devuan)" \
    debian 'Debian' "$(v87_choice_state "$cur" debian)" \
    ubuntu 'Ubuntu' "$(v87_choice_state "$cur" ubuntu)" \
    alpine 'Alpine Linux (OpenRC)' "$(v87_choice_state "$cur" alpine)" \
    arch 'Arch Linux' "$(v87_choice_state "$cur" arch)" \
    void 'Void Linux (runit)' "$(v87_choice_state "$cur" void)" \
    fedora 'Fedora / Ultramarine' "$(v87_choice_state "$cur" fedora)" \
    gentoo 'Gentoo stage3' "$(v87_choice_state "$cur" gentoo)") || return
  case $d in
    devuan) rel=excalibur; boot=debootstrap; init=sysvinit; mirror='https://deb.devuan.org/merged'; name=Devuan;;
    debian) rel=trixie; boot=debootstrap; init=sysvinit; mirror='https://deb.debian.org/debian'; name=Debian;;
    ubuntu) rel=noble; boot=debootstrap; init=sysvinit; mirror='https://ports.ubuntu.com/ubuntu-ports'; name=Ubuntu;;
    alpine) rel=v3.22; boot=apk; init=openrc; mirror='https://dl-cdn.alpinelinux.org/alpine'; name=Alpine;;
    arch) rel=rolling; boot=pacstrap; init=sysvinit; mirror=''; name=Arch;;
    void) rel=current; boot=xbps; init=runit; mirror='https://repo-default.voidlinux.org/current/aarch64'; name=Void;;
    fedora) rel=43; boot=dnf; init=sysvinit; mirror=''; name=Fedora;;
    gentoo) rel=stage3; boot=stage3; init=openrc; mirror=''; name=Gentoo;;
  esac
  v87_profile_set "$V87_BUILD_PROFILE" DISTRO "$d"
  v87_profile_set "$V87_BUILD_PROFILE" RELEASE "$rel"
  v87_profile_set "$V87_BUILD_PROFILE" BOOTSTRAP "$boot"
  v87_profile_set "$V87_BUILD_PROFILE" INIT "$init"
  v87_profile_set "$V87_BUILD_PROFILE" MIRROR "$mirror"
  arch=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH); [ -n "$arch" ] || arch=arm64
  v87_profile_set "$V87_BUILD_PROFILE" DEST "/AOK/roots/$name-$rel-$arch"
}

v87_profile_choose_arch(){
  cur=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH); [ -n "$cur" ] || cur=arm64
  a=$(ui_radiolist 'Build profile: Architecture' 'Select the RootFS architecture supported by iSH-AOK.' \
    arm64 'ARM64 / AArch64' "$(v87_choice_state "$cur" arm64)" \
    i386 '32-bit x86' "$(v87_choice_state "$cur" i386)" \
    amd64 '64-bit x86' "$(v87_choice_state "$cur" amd64)" \
    riscv64 '64-bit RISC-V' "$(v87_choice_state "$cur" riscv64)") || return
  v87_profile_set "$V87_BUILD_PROFILE" ARCH "$a"
  d=$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO); r=$(v87_profile_get "$V87_BUILD_PROFILE" RELEASE)
  n=$(printf '%s' "$d" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
  v87_profile_set "$V87_BUILD_PROFILE" DEST "/AOK/roots/$n-$r-$a"
}

v87_profile_choose_bootstrap(){
  cur=$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP); [ -n "$cur" ] || cur=debootstrap
  b=$(ui_radiolist 'Build profile: Bootstrap method' 'Choose the builder backend.' \
    debootstrap 'Debian, Devuan or Ubuntu debootstrap' "$(v87_choice_state "$cur" debootstrap)" \
    mmdebstrap 'Debian-family mmdebstrap' "$(v87_choice_state "$cur" mmdebstrap)" \
    apk 'Alpine apk --root' "$(v87_choice_state "$cur" apk)" \
    pacstrap 'Arch pacstrap' "$(v87_choice_state "$cur" pacstrap)" \
    dnf 'Fedora/Ultramarine DNF installroot' "$(v87_choice_state "$cur" dnf)" \
    xbps 'Void XBPS installroot' "$(v87_choice_state "$cur" xbps)" \
    stage3 'Gentoo/custom tarball import' "$(v87_choice_state "$cur" stage3)" \
    build_fs 'Native /opt/AOK/build_fs' "$(v87_choice_state "$cur" build_fs)") || return
  v87_profile_set "$V87_BUILD_PROFILE" BOOTSTRAP "$b"
}

v87_profile_choose_packages(){
  cur=$(v87_profile_get "$V87_BUILD_PROFILE" PACKAGES)
  has(){ case " $cur " in *" $1 "*) printf on;; *) printf off;; esac; }
  sel=$(ui_checklist 'Build profile: Package groups' 'Select package groups. The generated list remains editable through this wizard.' \
    base 'Core utilities and process tools' "$(has coreutils)" \
    shell 'Bash, completion and shell utilities' "$(has bash)" \
    editor 'nano, vim and editor basics' "$(has nano)" \
    network 'curl, wget, ping, certificates and DNS tools' "$(has curl)" \
    ssh 'OpenSSH client and server' "$(has openssh-server)" \
    admin 'sudo/doas, passwd and user management' "$(has sudo)" \
    services 'cron, logging, time synchronization and logrotate' "$(has cron)" \
    build 'compiler, make, cmake, pkg-config and git' "$(has cmake)" \
    docs 'man pages, less and file utilities' "$(has man-db)") || return
  p=''
  for g in $sel; do case $g in
    base) p="$p coreutils findutils grep sed gawk diffutils procps file less";;
    shell) p="$p bash bash-completion";;
    editor) p="$p nano vim";;
    network) p="$p ca-certificates curl wget iputils-ping openssl";;
    ssh) p="$p openssh-client openssh-server";;
    admin) p="$p passwd adduser sudo";;
    services) p="$p cron logrotate rsyslog chrony tzdata locales";;
    build) p="$p build-essential cmake make pkg-config git";;
    docs) p="$p man-db manpages less file";;
  esac; done
  p=$(printf '%s\n' "$p" | awk '{$1=$1;print}')
  v87_profile_set "$V87_BUILD_PROFILE" PACKAGES "$p"
}

v87_profile_choose_options(){
  ssh=$(v87_profile_get "$V87_BUILD_PROFILE" ENABLE_SSH); sudo=$(v87_profile_get "$V87_BUILD_PROFILE" ENABLE_SUDO)
  net=$(v87_profile_get "$V87_BUILD_PROFILE" ENABLE_NETWORK); dns=$(v87_profile_get "$V87_BUILD_PROFILE" COPY_DNS)
  second=$(v87_profile_get "$V87_BUILD_PROFILE" RUN_SECOND_STAGE); reg=$(v87_profile_get "$V87_BUILD_PROFILE" REGISTER_ROOTFS)
  proj=$(v87_profile_get "$V87_BUILD_PROFILE" CREATE_PROJECT)
  sel=$(ui_checklist 'Build profile: Features' 'Select post-bootstrap configuration features.' \
    ssh 'Enable and configure OpenSSH server' "$(v87_yes_state "$ssh")" \
    sudo 'Configure administrator access' "$(v87_yes_state "$sudo")" \
    network 'Configure basic networking files' "$(v87_yes_state "$net")" \
    dns 'Copy host resolver configuration' "$(v87_yes_state "$dns")" \
    second 'Run bootstrap second stage when required' "$(v87_yes_state "$second")" \
    register 'Register successful RootFS' "$(v87_yes_state "$reg")" \
    project 'Create a v8 RootFS project' "$(v87_yes_state "$proj")") || return
  for k in ENABLE_SSH ENABLE_SUDO ENABLE_NETWORK COPY_DNS RUN_SECOND_STAGE REGISTER_ROOTFS CREATE_PROJECT; do v87_profile_set "$V87_BUILD_PROFILE" "$k" no; done
  for x in $sel; do case $x in ssh) k=ENABLE_SSH;; sudo) k=ENABLE_SUDO;; network) k=ENABLE_NETWORK;; dns) k=COPY_DNS;; second) k=RUN_SECOND_STAGE;; register) k=REGISTER_ROOTFS;; project) k=CREATE_PROJECT;; esac; v87_profile_set "$V87_BUILD_PROFILE" "$k" yes; done
}

v87_profile_choose_identity(){
  for spec in 'PROFILE_NAME|Profile name|default' 'RELEASE|Distribution release|excalibur' 'DEST|Destination RootFS path|/AOK/roots/rootfs' 'MIRROR|Repository mirror URL|' 'HOSTNAME|Hostname|ish-aok' 'USER_NAME|Default user name|user' 'LOCALE|Locale|C.UTF-8' 'TIMEZONE|Timezone|UTC'; do
    k=${spec%%|*}; rest=${spec#*|}; label=${rest%%|*}; def=${rest#*|}; cur=$(v87_profile_get "$V87_BUILD_PROFILE" "$k"); [ -n "$cur" ] || cur=$def
    val=$(ui_input 'Build profile: Identity and paths' "$label" "$cur") || return
    v87_profile_set "$V87_BUILD_PROFILE" "$k" "$val"
  done
}

v87_profile_choose_init_shell(){
  cur=$(v87_profile_get "$V87_BUILD_PROFILE" INIT); init=$(ui_radiolist 'Build profile: Init system' 'Select the desired userspace init layout.' \
    sysvinit 'SysVinit' "$(v87_choice_state "$cur" sysvinit)" openrc 'OpenRC' "$(v87_choice_state "$cur" openrc)" runit 'runit' "$(v87_choice_state "$cur" runit)" none 'No init conversion' "$(v87_choice_state "$cur" none)") || return
  v87_profile_set "$V87_BUILD_PROFILE" INIT "$init"
  cur=$(v87_profile_get "$V87_BUILD_PROFILE" SHELL_PATH); shell=$(ui_radiolist 'Build profile: Default shell' 'Select the default interactive shell.' \
    /bin/bash 'Bash' "$(v87_choice_state "$cur" /bin/bash)" /bin/sh 'POSIX sh' "$(v87_choice_state "$cur" /bin/sh)" /bin/ash 'Ash' "$(v87_choice_state "$cur" /bin/ash)" /bin/zsh 'Zsh' "$(v87_choice_state "$cur" /bin/zsh)") || return
  v87_profile_set "$V87_BUILD_PROFILE" SHELL_PATH "$shell"
}

v87_profile_choose_compression(){ cur=$(v87_profile_get "$V87_BUILD_PROFILE" COMPRESSION); c=$(ui_radiolist 'Build profile: Compression' 'Select the default export format.' zstd 'zstd: fast and compact' "$(v87_choice_state "$cur" zstd)" gzip 'gzip: broadly compatible' "$(v87_choice_state "$cur" gzip)" xz 'xz: smaller and slower' "$(v87_choice_state "$cur" xz)" none 'No automatic archive' "$(v87_choice_state "$cur" none)") || return; v87_profile_set "$V87_BUILD_PROFILE" COMPRESSION "$c"; }

v87_profile_validate(){
  v87_profile_defaults; errors='';
  for k in DISTRO RELEASE ARCH DEST BOOTSTRAP INIT SHELL_PATH; do v=$(v87_profile_get "$V87_BUILD_PROFILE" "$k"); [ -n "$v" ] || errors="$errors\nMissing: $k"; done
  dest=$(v87_profile_get "$V87_BUILD_PROFILE" DEST); case $dest in /*) :;; *) errors="$errors\nDEST must be an absolute path";; esac
  arch=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH); case $arch in arm64|aarch64|i386|amd64|x86_64|riscv64) :;; *) errors="$errors\nUnsupported ARCH: $arch";; esac
  boot=$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP); case $boot in debootstrap|mmdebstrap|apk|pacstrap|dnf|xbps|stage3|build_fs) :;; *) errors="$errors\nUnknown BOOTSTRAP: $boot";; esac
  [ -z "$errors" ] || { ui_msg 'Build profile validation' "Validation failed:$errors"; return 1; }
  ui_msg 'Build profile validation' 'Profile is valid.'
}

v87_profile_summary(){ v87_profile_defaults; ui_text 'Build profile summary' "Profile: $(v87_profile_get "$V87_BUILD_PROFILE" PROFILE_NAME)\nDistribution: $(v87_profile_get "$V87_BUILD_PROFILE" DISTRO) $(v87_profile_get "$V87_BUILD_PROFILE" RELEASE)\nArchitecture: $(v87_profile_get "$V87_BUILD_PROFILE" ARCH)\nBootstrap: $(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP)\nDestination: $(v87_profile_get "$V87_BUILD_PROFILE" DEST)\nInit: $(v87_profile_get "$V87_BUILD_PROFILE" INIT)\nShell: $(v87_profile_get "$V87_BUILD_PROFILE" SHELL_PATH)\nPackages: $(v87_profile_get "$V87_BUILD_PROFILE" PACKAGES)\nSSH: $(v87_profile_get "$V87_BUILD_PROFILE" ENABLE_SSH)\nRegister RootFS: $(v87_profile_get "$V87_BUILD_PROFILE" REGISTER_ROOTFS)\nCreate project: $(v87_profile_get "$V87_BUILD_PROFILE" CREATE_PROJECT)\n\nFile: $V87_BUILD_PROFILE"; }

v87_build_profile_wizard(){
  v87_profile_defaults
  while :; do
    c=$(ui_menu 'Build Profile Wizard' 'Configure the RootFS build profile using selection lists and guided fields.' \
      distro 'Distribution preset' arch 'Architecture' bootstrap 'Bootstrap backend' packages 'Package groups' features 'Build features' identity 'Identity, release and paths' init 'Init system and default shell' compression 'Archive compression' summary 'Review profile summary' validate 'Validate profile' reset 'Reset to recommended defaults') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      distro) v87_profile_choose_distro;; arch) v87_profile_choose_arch;; bootstrap) v87_profile_choose_bootstrap;; packages) v87_profile_choose_packages;; features) v87_profile_choose_options;; identity) v87_profile_choose_identity;; init) v87_profile_choose_init_shell;; compression) v87_profile_choose_compression;; summary) v87_profile_summary;; validate) v87_profile_validate;; reset) ui_yesno Reset 'Replace the current profile with recommended defaults?' && { rm -f "$V87_BUILD_PROFILE"; v87_profile_defaults; };;
    esac
  done
}

aok_build_profile_file(){ v87_profile_defaults; printf '%s' "$V87_BUILD_PROFILE"; }
aok_build_profile_edit(){ v87_build_profile_wizard; }
aok_build_show(){ v87_profile_summary; }

v87_build_execute(){
  v87_profile_defaults; v87_profile_validate || return
  boot=$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP)
  case $boot in debootstrap|mmdebstrap) aok_builder_debootstrap;; apk) aok_builder_apk;; pacstrap) aok_builder_pacstrap;; dnf) aok_builder_dnf;; xbps) aok_builder_xbps;; stage3) aok_fs_extract;; build_fs) aok_build_fs_wrapper;; esac
}

# Canonical builder menu used by v8 platform, studios and legacy callers.
aok_build_menu(){
  while :; do
    c=$(ui_menu 'RootFS Builder' 'Create or import RootFS filesystems using the guided v8 build profile.' \
      profile 'Configure build profile (guided)' summary 'Review current build profile' validate 'Validate build profile' execute 'Build using current profile' recipes 'Build recipes' queue 'Build queue' import 'Import existing RootFS' logs 'Build logs and diagnostics' cleanup 'Clean failed build directory' advanced 'Advanced/manual builder tools') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      profile) v87_build_profile_wizard;; summary) v87_profile_summary;; validate) v87_profile_validate;; execute) v87_build_execute;; recipes) build_recipes_menu;; queue) aok_build_queue_menu;; import) rootfs_import_export_studio;; logs) aok_build_logs;; cleanup) aok_build_clean;; advanced) v87_manual_builders_menu;;
    esac
  done
}

v87_manual_builders_menu(){ while :; do c=$(ui_menu 'Advanced builder tools' 'Direct builder backends and compatibility wrappers.' buildfs 'Run /opt/AOK/build_fs' debootstrap 'Debootstrap directly' apk 'APK --root directly' pacstrap 'Pacstrap directly' dnf 'DNF installroot directly' xbps 'XBPS installroot directly' stage3 'Stage3/custom archive importer' directory 'Directory importer' shell 'Open shell in build directory') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in buildfs) aok_build_fs_wrapper;; debootstrap) aok_builder_debootstrap;; apk) aok_builder_apk;; pacstrap) aok_builder_pacstrap;; dnf) aok_builder_dnf;; xbps) aok_builder_xbps;; stage3) aok_fs_extract;; directory) aok_import_directory;; shell) d=$(ui_input Shell 'Build directory' /opt/AOK) || continue; (cd "$d" && ${SHELL:-/bin/sh});; esac; done; }

aok_builder_studio(){
  while :; do
    c=$(ui_menu 'RootFS Build Studio' "Active RootFS: $(active_rootfs)" \
      profile 'Guided build-profile configuration' build 'Build or import a RootFS' recipes 'Reusable build recipes' queue 'Build queue and plans' projects 'RootFS projects' validate 'Preflight and compatibility checks' artifacts 'Artifacts, archives and exports' overlays 'Overlay management' reports 'Build reports and logs') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in profile) v87_build_profile_wizard;; build) aok_build_menu;; recipes) build_recipes_menu;; queue) aok_build_queue_menu;; projects) rootfs_projects_menu;; validate) aok_advanced_tools_menu;; artifacts) rootfs_import_export_studio;; overlays) overlay_studio_menu_v72 2>/dev/null || aok_more_options_menu;; reports) aok_build_logs;; esac
  done
}

aok_build_manage_menu(){ aok_builder_studio; }

# Cleaned studio navigation: build/project operations are not duplicated elsewhere.
aok_v7_studios_menu(){
  while :; do
    c=$(ui_menu 'RootFS Studios' "Active: $(active_rootfs)" \
      build 'Build Studio' manager 'RootFS Manager' health 'Health Dashboard' repair 'Repair Studio' chroot 'Chroot Studio' package 'Package Studio' snapshots 'Snapshot Studio' compatibility 'Compatibility Studio' transfer 'Import and Export Studio' optimize 'Optimization Studio' reports 'Reports Studio') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in build) aok_builder_studio;; manager) rootfs_manager_menu;; health) rootfs_health_dashboard;; repair) rootfs_repair_studio;; chroot) chroot_studio_menu;; package) package_center_v6;; snapshots) aok_snapshots_menu;; compatibility) rootfs_compatibility_studio;; transfer) rootfs_import_export_studio;; optimize) rootfs_optimization_studio;; reports) rootfs_reports_studio;; esac
  done
}

platform_v80_menu(){
  while :; do
    c=$(ui_menu 'v8 RootFS Platform' "Active: $(active_rootfs)" \
      build 'Build Studio and profiles' projects 'RootFS Projects' workspace 'Multi-RootFS Workspace' monitor 'Platform monitoring' automation 'Workflows and automation' extensions 'Plugin Repository and SDK' reports 'Documentation and visualization' remote 'Remote RootFS profiles') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in build) aok_builder_studio;; projects) rootfs_projects_menu;; workspace) multi_rootfs_menu;; monitor) platform_monitor_menu;; automation) aok_v71_workflows_menu;; extensions) plugin_repository_menu;; reports) v87_platform_reports_menu;; remote) remote_rootfs_menu;; esac
  done
}

v87_platform_reports_menu(){ while :; do c=$(ui_menu 'Platform reports and documentation' 'Reports, diffs, generated documentation and workflow visualization.' diff 'Advanced RootFS diff' docs 'Documentation generator' visualizer 'Workflow visualizer' platform 'Platform report' build 'Build profile summary') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in diff) rootfs_deep_diff;; docs) documentation_generator_menu;; visualizer) workflow_visualizer_menu;; platform) ui_text Platform "$(platform_v80_report)";; build) v87_profile_summary;; esac; done; }

# Optimized AOK home: one canonical route per task.
aok_menu(){
  while :; do
    c=$(ui_menu 'iSH-AOK and RootFS' "Active RootFS: $(active_rootfs)\nBuild, manage, repair and automate RootFS filesystems." \
      dashboard 'RootFS dashboard and selection' build 'Build Studio' manage 'RootFS Studios' platform 'Projects and multi-RootFS platform' workflows 'Workflows and automation' repair 'Chroot, repair and recovery' configure 'Repositories, services and optimization' advanced 'Diagnostics and advanced tools') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in dashboard) aok_context_menu;; build) aok_builder_studio;; manage) aok_v7_studios_menu;; platform) platform_v80_menu;; workflows) aok_v71_workflows_menu;; repair) aok_chroot_repair_menu;; configure) aok_configure_menu;; advanced) aok_advanced_menu;; esac
  done
}

v87_build_profile_report(){ v87_profile_defaults; cat "$V87_BUILD_PROFILE"; }
