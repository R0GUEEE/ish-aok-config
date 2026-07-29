#!/bin/sh
# v11.6 focused Mini RootFS configuration and direct build workflow.

V1160_STATE_DIR=${V1160_STATE_DIR:-${V1101_STATE_DIR:-$STATE_DIR/builder-v11}/mini-rootfs}
V1160_CONFIG=${V1160_CONFIG:-$V1160_STATE_DIR/current.conf}
V1160_TEMPLATE_DIR=${V1160_TEMPLATE_DIR:-$V1160_STATE_DIR/templates}
V1160_LOG_DIR=${V1160_LOG_DIR:-$V1160_STATE_DIR/logs}
V1160_ROOT_PASSWORD=${V1160_ROOT_PASSWORD:-}
V1160_USER_PASSWORD=${V1160_USER_PASSWORD:-}

v1160_get(){ sed -n "s/^$1=//p" "$V1160_CONFIG" 2>/dev/null | tail -n 1; }
v1160_set(){
  _v1160_key=$1 _v1160_value=$2
  mkdir -p "$V1160_STATE_DIR" 2>/dev/null || return 1
  _v1160_tmp=$V1160_CONFIG.tmp.$$
  { grep -v "^${_v1160_key}=" "$V1160_CONFIG" 2>/dev/null || true; printf '%s=%s\n' "$_v1160_key" "$_v1160_value"; } >"$_v1160_tmp" &&
    mv "$_v1160_tmp" "$V1160_CONFIG"
}

v1160_release_default(){
  case $1 in
    debian) printf trixie;;
    devuan) printf excalibur;;
    ubuntu) printf noble;;
    alpine) printf latest-stable;;
    arch) printf rolling;;
    fedora) printf 43;;
    void) printf current;;
    gentoo) printf current;;
    *) printf stable;;
  esac
}

v1160_arches(){
  _v1160_file=${V1101_DATA_DIR:-$ISH_AOK_CONFIG_ROOT/data/v11}/distributions/$1.conf
  _v1160_arches=$(sed -n 's/^ARCHES=//p' "$_v1160_file" 2>/dev/null | head -n 1)
  [ -n "$_v1160_arches" ] && printf '%s\n' "$_v1160_arches" || printf 'x86 x86_64 aarch64\n'
}

v1160_arch_default(){
  _v1160_distro=$1 _v1160_host=${ARCH:-$(uname -m 2>/dev/null || printf x86)}
  _v1160_choices=$(v1160_arches "$_v1160_distro")
  case " $_v1160_choices " in *" $_v1160_host "*) printf '%s' "$_v1160_host"; return;; esac
  case $_v1160_host in
    i?86|x86) for _v1160_a in x86 i386; do case " $_v1160_choices " in *" $_v1160_a "*) printf '%s' "$_v1160_a"; return;; esac; done;;
    x86_64|amd64) for _v1160_a in x86_64 amd64; do case " $_v1160_choices " in *" $_v1160_a "*) printf '%s' "$_v1160_a"; return;; esac; done;;
    aarch64|arm64) for _v1160_a in aarch64 arm64; do case " $_v1160_choices " in *" $_v1160_a "*) printf '%s' "$_v1160_a"; return;; esac; done;;
  esac
  set -- $_v1160_choices; printf '%s' "${1:-x86}"
}

v1160_init_default(){
  case $1 in alpine|gentoo) printf openrc;; devuan|debian|ubuntu) printf sysvinit;; void) printf runit;; *) printf none;; esac
}

v1160_init_choices(){
  case $1 in
    debian|devuan|ubuntu) printf 'sysvinit openrc none\n';;
    alpine|gentoo) printf 'openrc none\n';;
    void) printf 'runit none\n';;
    arch|fedora) printf 'none systemd\n';;
    *) printf 'none\n';;
  esac
}

v1160_mirror_default(){
  case $1 in
    debian) printf 'https://deb.debian.org/debian';;
    devuan) printf 'https://deb.devuan.org/merged';;
    ubuntu) case $2 in amd64|i386) printf 'https://archive.ubuntu.com/ubuntu';; *) printf 'https://ports.ubuntu.com/ubuntu-ports';; esac;;
    alpine) printf 'https://dl-cdn.alpinelinux.org/alpine';;
    void) printf 'https://repo-default.voidlinux.org/current';;
    *) printf '';;
  esac
}

v1160_target_default(){ printf '/AOK/roots/mini-%s' "$1"; }
v1160_hostname_default(){ printf 'mini-%s' "$1"; }
v1160_output_default(){ printf '/AOK/artifacts/mini-%s-%s.tar.%s' "$1" "$2" "$3"; }

v1160_reset_for_distro(){
  _v1160_distro=$1
  v1160_set DISTRO "$_v1160_distro"
  v1160_set RELEASE "$(v1160_release_default "$_v1160_distro")"
  v1160_set ARCH "$(v1160_arch_default "$_v1160_distro")"
  v1160_set INIT "$(v1160_init_default "$_v1160_distro")"
  v1160_set TARGET "$(v1160_target_default "$_v1160_distro")"
  v1160_set HOSTNAME "$(v1160_hostname_default "$_v1160_distro")"
  v1160_set MIRROR "$(v1160_mirror_default "$_v1160_distro" "$(v1160_get ARCH)")"
  v1160_set SOURCE ''
  case $(v1160_get COMPRESSION) in gzip) _v1160_ext=gz;; xz) _v1160_ext=xz;; none) _v1160_ext=;; *) _v1160_ext=zst;; esac
  [ -n "$_v1160_ext" ] && v1160_set OUTPUT "$(v1160_output_default "$_v1160_distro" "$(v1160_get ARCH)" "$_v1160_ext")" || v1160_set OUTPUT ''
}

v1160_defaults(){
  [ -r "$V1160_CONFIG" ] && return 0
  mkdir -p "$V1160_STATE_DIR" "$V1160_TEMPLATE_DIR" "$V1160_LOG_DIR" 2>/dev/null || return 1
  {
    printf 'DISTRO=alpine\nRELEASE=latest-stable\nARCH=x86\nINIT=openrc\n'
    printf 'PRESETS=minimal\nCUSTOM_PACKAGES=\nTARGET=/AOK/roots/mini-alpine\n'
    printf 'HOSTNAME=mini-alpine\nUSERNAME=\nROOT_LOGIN=locked\n'
    printf 'COMPRESSION=zstd\nOUTPUT=/AOK/artifacts/mini-alpine-x86.tar.zst\n'
    printf 'MIRROR=https://dl-cdn.alpinelinux.org/alpine\nSOURCE=\n'
  } >"$V1160_CONFIG"
}

v1160_backend(){
  case $(v1160_get DISTRO) in
    debian|devuan|ubuntu) printf debootstrap;; alpine) printf apk;; arch) printf pacstrap;;
    fedora) printf dnf;; void) printf xbps-install;; gentoo) printf stage3;; *) printf unknown;;
  esac
}

v1160_init_packages(){
  _v1160_distro=$(v1160_get DISTRO) _v1160_init=$(v1160_get INIT)
  case $_v1160_distro:$_v1160_init in
    debian:sysvinit|devuan:sysvinit|ubuntu:sysvinit) printf 'sysvinit-core sysvinit-utils';;
    debian:openrc|devuan:openrc|ubuntu:openrc|alpine:openrc|gentoo:openrc) printf openrc;;
    void:runit) printf runit;;
  esac
}

v1160_packages(){
  _v1160_sets=$(v1160_get PRESETS); [ -n "$_v1160_sets" ] || _v1160_sets=minimal
  {
    v1101_packages_for_sets "$(printf '%s' "$_v1160_sets" | tr ' ' ',')" "$(v1160_get DISTRO)" 2>/dev/null || true
    printf ' %s %s\n' "$(v1160_get CUSTOM_PACKAGES)" "$(v1160_init_packages)"
  } | tr ' ' '\n' | sed '/^$/d' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/ $//'
}

v1160_package_count(){ set -- $(v1160_packages); printf '%s' "$#"; }
v1160_password_state(){ [ -n "$1" ] && printf set || printf 'not set'; }
v1160_target_safe(){
  case $1 in
    /*) :;;
    *) return 1;;
  esac
  case $1 in /|/AOK|/opt|/opt/AOK|/root|/home|/usr|/etc|/var|/bin|/sbin|/lib|/lib64) return 1;; esac
  return 0
}

v1160_summary(){
  printf 'Distribution:  %s %s\n' "$(v1160_get DISTRO)" "$(v1160_get RELEASE)"
  printf 'Architecture:  %s\nInit system:   %s\nBackend:       %s\n' "$(v1160_get ARCH)" "$(v1160_get INIT)" "$(v1160_backend)"
  printf 'Package sets:  %s\nCustom:        %s\nPackages:      %s resolved\n' "$(v1160_get PRESETS)" "$(v1160_get CUSTOM_PACKAGES)" "$(v1160_package_count)"
  printf 'Target:        %s\nHostname:      %s\nUser:          %s\n' "$(v1160_get TARGET)" "$(v1160_get HOSTNAME)" "$(v1160_get USERNAME)"
  printf 'Root login:    %s (password %s this session)\n' "$(v1160_get ROOT_LOGIN)" "$(v1160_password_state "$V1160_ROOT_PASSWORD")"
  [ -n "$(v1160_get USERNAME)" ] && printf 'User password: %s this session\n' "$(v1160_password_state "$V1160_USER_PASSWORD")"
  printf 'Compression:   %s\nOutput:        %s\nMirror:        %s\n' "$(v1160_get COMPRESSION)" "$(v1160_get OUTPUT)" "$(v1160_get MIRROR)"
  [ -n "$(v1160_get SOURCE)" ] && printf 'Source:        %s\n' "$(v1160_get SOURCE)"
}

v1160_header(){
  printf '%s %s / %s / %s\n%s packages -> %s' "$(v1160_get DISTRO)" "$(v1160_get RELEASE)" "$(v1160_get ARCH)" "$(v1160_get INIT)" "$(v1160_package_count)" "$(v1160_get TARGET)"
}

v1160_distro_menu(){
  _v1160_current=$(v1160_get DISTRO); set --
  for _v1160_d in alpine debian devuan ubuntu arch fedora void gentoo; do
    case $_v1160_d in alpine) _v1160_label='Alpine Linux';; arch) _v1160_label='Arch Linux';; void) _v1160_label='Void Linux';; gentoo) _v1160_label='Gentoo Linux';; *) _v1160_label=$_v1160_d;; esac
    _v1160_state=off; [ "$_v1160_d" = "$_v1160_current" ] && _v1160_state=on
    set -- "$@" "$_v1160_d" "$_v1160_label" "$_v1160_state"
  done
  _v1160_selected=$(ui_radiolist Distribution 'Choose the distribution for the mini RootFS.' "$@") || return 0
  [ -n "$_v1160_selected" ] || return 0
  [ "$_v1160_selected" = "$_v1160_current" ] || v1160_reset_for_distro "$_v1160_selected"
  _v1160_release=$(ui_input Release 'Release, suite, branch or version:' "$(v1160_get RELEASE)") || return 0
  [ -n "$_v1160_release" ] && v1160_set RELEASE "$_v1160_release"
  set --
  for _v1160_a in $(v1160_arches "$_v1160_selected"); do
    _v1160_state=off; [ "$_v1160_a" = "$(v1160_get ARCH)" ] && _v1160_state=on
    set -- "$@" "$_v1160_a" "$_v1160_a" "$_v1160_state"
  done
  _v1160_arch=$(ui_radiolist Architecture 'Choose the target CPU architecture.' "$@") || return 0
  [ -n "$_v1160_arch" ] && v1160_set ARCH "$_v1160_arch"
  v1160_set MIRROR "$(v1160_mirror_default "$_v1160_selected" "$(v1160_get ARCH)")"
  if [ "$_v1160_selected" = gentoo ]; then
    _v1160_source=$(ui_input 'Gentoo stage3' 'Local stage3 archive path:' "$(v1160_get SOURCE)") || return 0
    v1160_set SOURCE "$_v1160_source"
  fi
}

v1160_init_menu(){
  _v1160_current=$(v1160_get INIT); set --
  for _v1160_i in $(v1160_init_choices "$(v1160_get DISTRO)"); do
    case $_v1160_i in none) _v1160_label='No boot init (smallest; ideal for chroot/proot)';; systemd) _v1160_label='systemd (limited inside iSH)';; sysvinit) _v1160_label='SysVinit';; openrc) _v1160_label='OpenRC';; runit) _v1160_label='runit';; esac
    _v1160_state=off; [ "$_v1160_i" = "$_v1160_current" ] && _v1160_state=on
    set -- "$@" "$_v1160_i" "$_v1160_label" "$_v1160_state"
  done
  _v1160_selected=$(ui_radiolist 'Init system' 'Only init systems available for this distribution are shown.' "$@") || return 0
  [ -n "$_v1160_selected" ] && v1160_set INIT "$_v1160_selected"
}

v1160_packages_menu(){
  _v1160_current=" $(v1160_get PRESETS) "; set --
  while IFS='|' read -r _v1160_id _v1160_label _v1160_desc _v1160_file; do
    [ -n "$_v1160_id" ] || continue
    _v1160_state=off; case $_v1160_current in *" $_v1160_id "*) _v1160_state=on;; esac
    set -- "$@" "$_v1160_id" "$_v1160_label — $_v1160_desc" "$_v1160_state"
  done <<EOF_V1160_SETS
$(v1101_package_set_list)
EOF_V1160_SETS
  _v1160_selected=$(ui_checklist 'Package presets' 'Use Space to select one or more presets. Minimal is recommended.' "$@") || return 0
  _v1160_selected=$(printf '%s\n' "$_v1160_selected" | tr '\n' ' ' | sed 's/ *$//')
  [ -n "$_v1160_selected" ] || _v1160_selected=minimal
  v1160_set PRESETS "$_v1160_selected"
  _v1160_custom=$(ui_input 'Custom packages' 'Extra package names separated by spaces:' "$(v1160_get CUSTOM_PACKAGES)") || return 0
  case $_v1160_custom in *[!A-Za-z0-9+_.:@/\ -]*) ui_msg Packages 'Custom package names contain unsupported characters.';; *) v1160_set CUSTOM_PACKAGES "$_v1160_custom";; esac
}

v1160_location_menu(){
  _v1160_target=$(ui_input 'Target directory' 'Empty directory for the new RootFS:' "$(v1160_get TARGET)") || return 0
  v1160_target_safe "$_v1160_target" || { ui_msg 'Target directory' 'Choose a dedicated absolute directory, not a system or iSH-AOK base directory.'; return 1; }
  v1160_set TARGET "$_v1160_target"
  _v1160_mirror=$(ui_input Mirror 'Package mirror (blank uses backend defaults):' "$(v1160_get MIRROR)") || return 0
  [ -n "$_v1160_mirror" ] || _v1160_mirror=$(v1160_mirror_default "$(v1160_get DISTRO)" "$(v1160_get ARCH)")
  v1160_set MIRROR "$_v1160_mirror"
}

v1160_password_prompt(){
  _v1160_title=$1 _v1160_first=$(ui_password "$_v1160_title" 'Enter password') || return 1
  [ -n "$_v1160_first" ] || { ui_msg "$_v1160_title" 'The password was left unchanged.'; return 1; }
  _v1160_second=$(ui_password "$_v1160_title" 'Confirm password') || return 1
  [ "$_v1160_first" = "$_v1160_second" ] || { ui_msg "$_v1160_title" 'Passwords did not match.'; return 1; }
  printf '%s' "$_v1160_first"
}

v1160_identity_menu(){
  _v1160_hostname=$(ui_input Identity 'Hostname:' "$(v1160_get HOSTNAME)") || return 0
  case $_v1160_hostname in ''|*[!A-Za-z0-9.-]*) ui_msg Identity 'Use letters, digits, dots and dashes for the hostname.'; return 1;; esac
  v1160_set HOSTNAME "$_v1160_hostname"
  _v1160_username=$(ui_input Identity 'Regular username (blank for none):' "$(v1160_get USERNAME)") || return 0
  case $_v1160_username in *[!a-z0-9_-]*|[0-9]*|root) ui_msg Identity 'Use a lowercase username that does not begin with a digit.'; return 1;; esac
  v1160_set USERNAME "$_v1160_username"
  _v1160_root_mode=$(ui_menu 'Root account' 'Choose root password behavior.' locked 'Keep root password locked' password 'Set a root password for this build') || return 0
  case $_v1160_root_mode in
    locked) V1160_ROOT_PASSWORD=; v1160_set ROOT_LOGIN locked;;
    password) _v1160_secret=$(v1160_password_prompt 'Root password') || return 0; V1160_ROOT_PASSWORD=$_v1160_secret; v1160_set ROOT_LOGIN password;;
  esac
  if [ -n "$_v1160_username" ]; then
    _v1160_secret=$(v1160_password_prompt 'User password') || return 0
    V1160_USER_PASSWORD=$_v1160_secret
  else
    V1160_USER_PASSWORD=
  fi
}

v1160_output_menu(){
  _v1160_current=$(v1160_get COMPRESSION); set --
  for _v1160_c in zstd gzip xz none; do
    case $_v1160_c in zstd) _v1160_label='Zstandard (.tar.zst) — fast and compact';; gzip) _v1160_label='gzip (.tar.gz) — most compatible';; xz) _v1160_label='XZ (.tar.xz) — smallest, slower';; none) _v1160_label='No archive — keep directory only';; esac
    _v1160_state=off; [ "$_v1160_c" = "$_v1160_current" ] && _v1160_state=on
    set -- "$@" "$_v1160_c" "$_v1160_label" "$_v1160_state"
  done
  _v1160_selected=$(ui_radiolist 'Compression output' 'Choose the final RootFS artifact.' "$@") || return 0
  v1160_set COMPRESSION "$_v1160_selected"
  [ "$_v1160_selected" = none ] && { v1160_set OUTPUT ''; return 0; }
  case $_v1160_selected in zstd) _v1160_ext=zst;; gzip) _v1160_ext=gz;; xz) _v1160_ext=xz;; esac
  _v1160_default=$(v1160_output_default "$(v1160_get DISTRO)" "$(v1160_get ARCH)" "$_v1160_ext")
  _v1160_output=$(ui_input 'Archive output' 'Output archive path:' "$_v1160_default") || return 0
  [ -n "$_v1160_output" ] || _v1160_output=$_v1160_default
  v1160_set OUTPUT "$_v1160_output"
}

v1160_template_file(){ printf '%s/%s.conf' "$V1160_TEMPLATE_DIR" "$1"; }
v1160_template_save(){
  _v1160_name=$(ui_input 'Save configuration' 'Template name:' "$(v1160_get DISTRO)-mini") || return 1
  case $_v1160_name in ''|*[!A-Za-z0-9._-]*) ui_msg Templates 'Use letters, digits, dots, dashes or underscores.'; return 1;; esac
  mkdir -p "$V1160_TEMPLATE_DIR" 2>/dev/null || return 1
  _v1160_file=$(v1160_template_file "$_v1160_name")
  [ -e "$_v1160_file" ] && ui_yesno Templates "Overwrite $_v1160_name?" || [ ! -e "$_v1160_file" ] || return 1
  {
    printf '# Passwords are intentionally excluded.\n'
    for _v1160_key in DISTRO RELEASE ARCH INIT PRESETS CUSTOM_PACKAGES TARGET HOSTNAME USERNAME ROOT_LOGIN COMPRESSION OUTPUT MIRROR SOURCE; do
      printf '%s=%s\n' "$_v1160_key" "$(v1160_get "$_v1160_key")"
    done
  } >"$_v1160_file" || return 1
  ui_msg Templates "Saved $_v1160_name. Passwords were not stored."
}

v1160_template_list(){
  for _v1160_file in "$V1160_TEMPLATE_DIR"/*.conf; do
    [ -r "$_v1160_file" ] || continue
    _v1160_name=$(basename "$_v1160_file" .conf)
    _v1160_distro=$(sed -n 's/^DISTRO=//p' "$_v1160_file" | tail -n 1)
    _v1160_arch=$(sed -n 's/^ARCH=//p' "$_v1160_file" | tail -n 1)
    printf '%s|%s — %s/%s\n' "$_v1160_name" "$_v1160_name" "$_v1160_distro" "$_v1160_arch"
  done
}

v1160_template_load(){
  set --
  while IFS='|' read -r _v1160_name _v1160_label; do [ -n "$_v1160_name" ] && set -- "$@" "$_v1160_name" "$_v1160_label"; done <<EOF_V1160_TEMPLATES
$(v1160_template_list)
EOF_V1160_TEMPLATES
  [ "$#" -gt 0 ] || { ui_msg Templates 'No saved configurations were found.'; return 1; }
  _v1160_name=$(ui_menu 'Load configuration' 'Choose a saved Mini RootFS configuration.' "$@") || return 1
  _v1160_file=$(v1160_template_file "$_v1160_name"); [ -r "$_v1160_file" ] || return 1
  for _v1160_key in DISTRO RELEASE ARCH INIT PRESETS CUSTOM_PACKAGES TARGET HOSTNAME USERNAME ROOT_LOGIN COMPRESSION OUTPUT MIRROR SOURCE; do
    _v1160_value=$(sed -n "s/^${_v1160_key}=//p" "$_v1160_file" | tail -n 1)
    grep -q "^${_v1160_key}=" "$_v1160_file" && v1160_set "$_v1160_key" "$_v1160_value"
  done
  V1160_ROOT_PASSWORD= V1160_USER_PASSWORD=
  ui_msg Templates "Loaded $_v1160_name. Set passwords again before building."
}

v1160_template_menu(){
  while :; do
    _v1160_choice=$(ui_menu Templates 'Save or load reusable build settings. Passwords are never stored.' save 'Save current configuration' load 'Load a configuration' back Back) || return 0
    case $_v1160_choice in save) v1160_template_save;; load) v1160_template_load;; back) return 0;; esac
  done
}

v1160_validate_token_list(){
  case $1 in *[!A-Za-z0-9+_.:@/\ -]*) return 1;; esac
  return 0
}

v1160_preflight(){
  _v1160_fail=0 _v1160_backend=$(v1160_backend) _v1160_target=$(v1160_get TARGET)
  printf 'Mini RootFS preflight\n\n'
  if v1160_target_safe "$_v1160_target"; then printf '[PASS] target: %s\n' "$_v1160_target"; else printf '[FAIL] unsafe target directory\n'; _v1160_fail=1; fi
  if [ -d "$_v1160_target" ] && [ -n "$(ls -A "$_v1160_target" 2>/dev/null)" ]; then printf '[FAIL] target directory is not empty\n'; _v1160_fail=1; else printf '[PASS] target is absent or empty\n'; fi
  if command -v "$_v1160_backend" >/dev/null 2>&1 || { [ "$_v1160_backend" = stage3 ] && [ -r "$(v1160_get SOURCE)" ]; }; then printf '[PASS] build backend: %s\n' "$_v1160_backend"; else printf '[FAIL] build backend unavailable: %s\n' "$_v1160_backend"; _v1160_fail=1; fi
  case $(v1160_get DISTRO) in debian|devuan|ubuntu|alpine|void) [ -n "$(v1160_get MIRROR)" ] || { printf '[FAIL] a package mirror is required for this distribution\n'; _v1160_fail=1; };; esac
  v1160_validate_token_list "$(v1160_get CUSTOM_PACKAGES)" && printf '[PASS] custom package names are safe\n' || { printf '[FAIL] custom package names are invalid\n'; _v1160_fail=1; }
  case $(v1160_get ROOT_LOGIN) in password) [ -n "$V1160_ROOT_PASSWORD" ] && printf '[PASS] root password supplied for this session\n' || { printf '[FAIL] root password must be entered again\n'; _v1160_fail=1; };; *) printf '[PASS] root password remains locked\n';; esac
  if [ -n "$(v1160_get USERNAME)" ]; then [ -n "$V1160_USER_PASSWORD" ] && printf '[PASS] user password supplied for this session\n' || { printf '[FAIL] regular-user password is missing\n'; _v1160_fail=1; }; fi
  case $(v1160_get COMPRESSION) in zstd) command -v zstd >/dev/null 2>&1 || { printf '[FAIL] zstd is not installed\n'; _v1160_fail=1; };; gzip) command -v gzip >/dev/null 2>&1 || { printf '[FAIL] gzip is not installed\n'; _v1160_fail=1; };; xz) command -v xz >/dev/null 2>&1 || { printf '[FAIL] xz is not installed\n'; _v1160_fail=1; };; esac
  _v1160_output=$(v1160_get OUTPUT)
  [ -n "$_v1160_output" ] && [ -e "$_v1160_output" ] && { printf '[FAIL] archive output already exists: %s\n' "$_v1160_output"; _v1160_fail=1; }
  [ "$_v1160_fail" -eq 0 ] && printf '\nREADY=yes\n' || printf '\nREADY=no\n'
  return "$_v1160_fail"
}

v1160_bootstrap(){
  _v1160_distro=$(v1160_get DISTRO) _v1160_release=$(v1160_get RELEASE) _v1160_arch=$(v1160_get ARCH)
  _v1160_target=$(v1160_get TARGET) _v1160_mirror=$(v1160_get MIRROR)
  as_root mkdir -p "$_v1160_target" || return 1
  case $_v1160_distro in
    debian|devuan|ubuntu)
      set -- debootstrap --variant=minbase --arch="$_v1160_arch"
      _v1160_keyring=$(v1101_keyring_for_target "$_v1160_distro" 2>/dev/null || true)
      [ -r "$_v1160_keyring" ] && set -- "$@" --keyring="$_v1160_keyring"
      set -- "$@" "$_v1160_release" "$_v1160_target"
      [ -n "$_v1160_mirror" ] && set -- "$@" "$_v1160_mirror"
      as_root "$@"
      ;;
    alpine)
      as_root apk --root "$_v1160_target" --arch "$_v1160_arch" --initdb \
        --repository "$_v1160_mirror/$_v1160_release/main" \
        --repository "$_v1160_mirror/$_v1160_release/community" add alpine-base || return 1
      v1160_target_write "$_v1160_target/etc/apk/repositories" 644 "$_v1160_mirror/$_v1160_release/main\n$_v1160_mirror/$_v1160_release/community\n"
      ;;
    arch) as_root pacstrap -c "$_v1160_target" base;;
    fedora) as_root dnf -y --installroot="$_v1160_target" --releasever="$_v1160_release" --forcearch="$_v1160_arch" install basesystem dnf;;
    void) as_root env XBPS_ARCH="$_v1160_arch" xbps-install -Sy -R "$_v1160_mirror" -r "$_v1160_target" base-minimal;;
    gentoo) as_root tar -xpf "$(v1160_get SOURCE)" -C "$_v1160_target";;
    *) return 1;;
  esac
}

v1160_install_packages(){
  _v1160_packages=$(v1160_packages); [ -n "$_v1160_packages" ] || return 0
  set -- $_v1160_packages
  _v1160_target=$(v1160_get TARGET)
  case $(v1160_get DISTRO) in
    debian|devuan|ubuntu)
      as_root chroot "$_v1160_target" apt-get update &&
        as_root chroot "$_v1160_target" env DEBIAN_FRONTEND=noninteractive apt-get install -y -- "$@"
      ;;
    alpine) as_root apk --root "$_v1160_target" add "$@";;
    arch) as_root pacstrap -c "$_v1160_target" "$@";;
    fedora) as_root dnf -y --installroot="$_v1160_target" install "$@";;
    void) as_root xbps-install -Sy -r "$_v1160_target" "$@";;
    gentoo) printf 'Gentoo package presets require emerge configuration after stage3 extraction.\n';;
  esac
}

v1160_target_write(){
  _v1160_path=$1 _v1160_mode=$2 _v1160_data=$3 _v1160_tmp=${TMP_DIR:-/tmp}/v1160-write.$$
  printf '%b' "$_v1160_data" >"$_v1160_tmp" || return 1
  as_root mkdir -p "$(dirname "$_v1160_path")" && as_root cp "$_v1160_tmp" "$_v1160_path" && as_root chmod "$_v1160_mode" "$_v1160_path"
  _v1160_rc=$?; rm -f "$_v1160_tmp"; return "$_v1160_rc"
}

v1160_configure_identity(){
  _v1160_target=$(v1160_get TARGET) _v1160_hostname=$(v1160_get HOSTNAME) _v1160_user=$(v1160_get USERNAME)
  v1160_target_write "$_v1160_target/etc/hostname" 644 "$_v1160_hostname\n" || return 1
  v1160_target_write "$_v1160_target/etc/hosts" 644 "127.0.0.1 localhost\n127.0.1.1 $_v1160_hostname\n" || return 1
  if [ -n "$_v1160_user" ]; then
    if [ -x "$_v1160_target/usr/sbin/useradd" ] || [ -x "$_v1160_target/sbin/useradd" ]; then as_root chroot "$_v1160_target" useradd -m -s /bin/sh "$_v1160_user";
    else as_root chroot "$_v1160_target" adduser -D -s /bin/sh "$_v1160_user"; fi || return 1
    printf '%s:%s\n' "$_v1160_user" "$V1160_USER_PASSWORD" | as_root chroot "$_v1160_target" chpasswd || return 1
  fi
  case $(v1160_get ROOT_LOGIN) in password) printf 'root:%s\n' "$V1160_ROOT_PASSWORD" | as_root chroot "$_v1160_target" chpasswd;; *) as_root chroot "$_v1160_target" passwd -l root;; esac
}

v1160_configure_init(){
  _v1160_target=$(v1160_get TARGET)
  case $(v1160_get INIT) in
    openrc)
      [ -d "$_v1160_target/etc/runlevels" ] || as_root mkdir -p "$_v1160_target/etc/runlevels/default"
      ;;
    sysvinit)
      v1160_target_write "$_v1160_target/etc/inittab" 644 'id:3:initdefault:\nsi::sysinit:/etc/init.d/rcS\nl0:0:wait:/etc/init.d/rc 0\nl1:1:wait:/etc/init.d/rc 1\nl2:2:wait:/etc/init.d/rc 2\nl3:3:wait:/etc/init.d/rc 3\nl4:4:wait:/etc/init.d/rc 4\nl5:5:wait:/etc/init.d/rc 5\nl6:6:wait:/etc/init.d/rc 6\n' || return 1
      ;;
  esac
}

v1160_archive(){
  _v1160_compression=$(v1160_get COMPRESSION); [ "$_v1160_compression" = none ] && return 0
  _v1160_target=$(v1160_get TARGET) _v1160_output=$(v1160_get OUTPUT)
  as_root mkdir -p "$(dirname "$_v1160_output")" || return 1
  case $_v1160_compression in
    gzip) as_root tar -C "$_v1160_target" --numeric-owner -czf "$_v1160_output" .;;
    xz) as_root tar -C "$_v1160_target" --numeric-owner -cJf "$_v1160_output" .;;
    zstd) as_root sh -c 'tar -C "$1" --numeric-owner -cf - . | zstd -T0 -q -o "$2"' sh "$_v1160_target" "$_v1160_output";;
  esac
}

v1160_manifest(){
  _v1160_manifest=$(v1160_get OUTPUT); [ -n "$_v1160_manifest" ] || _v1160_manifest=$(v1160_get TARGET)
  _v1160_manifest=${_v1160_manifest}.manifest
  _v1160_tmp=${TMP_DIR:-/tmp}/v1160-manifest.$$
  {
    printf 'format=ish-aok-mini-rootfs-v1\ncreated=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date)"
    for _v1160_key in DISTRO RELEASE ARCH INIT PRESETS CUSTOM_PACKAGES TARGET HOSTNAME USERNAME ROOT_LOGIN COMPRESSION OUTPUT MIRROR SOURCE; do printf '%s=%s\n' "$(printf '%s' "$_v1160_key" | tr '[:upper:]' '[:lower:]')" "$(v1160_get "$_v1160_key")"; done
    printf 'packages=%s\n' "$(v1160_packages)"
  } >"$_v1160_tmp"
  as_root cp "$_v1160_tmp" "$_v1160_manifest"; _v1160_rc=$?; rm -f "$_v1160_tmp"; return "$_v1160_rc"
}

v1160_execute(){
  v1160_bootstrap && v1160_install_packages && v1160_configure_identity && v1160_configure_init && v1160_archive && v1160_manifest
}

v1160_build(){
  if _v1160_report=$(v1160_preflight); then _v1160_ready=0; else _v1160_ready=$?; fi
  ui_text 'Build preflight' "$_v1160_report"
  [ "$_v1160_ready" -eq 0 ] || return 1
  ui_yesno 'Build Mini RootFS' "Build this configuration?\n\n$(v1160_summary)" || return 0
  mkdir -p "$V1160_LOG_DIR" 2>/dev/null || true
  if run_capture 'Build Mini RootFS' v1160_execute; then
    _v1160_artifact=$(v1160_get OUTPUT); [ -n "$_v1160_artifact" ] || _v1160_artifact='not requested'
    ui_msg 'Mini RootFS complete' "Created: $(v1160_get TARGET)\nArchive: $_v1160_artifact"
  else
    ui_msg 'Mini RootFS failed' "The target was left in place for inspection:\n$(v1160_get TARGET)"
    return 1
  fi
}

v1160_guided(){
  v1160_distro_menu || return
  v1160_init_menu || return
  v1160_packages_menu || return
  v1160_location_menu || return
  v1160_identity_menu || return
  v1160_output_menu || return
  ui_text 'Review Mini RootFS' "$(v1160_summary)\n\nResolved packages:\n$(v1160_packages | tr ' ' '\n')"
  v1160_build
}

v1160_rootfs_menu(){
  v1160_defaults || { ui_msg 'Mini RootFS' 'Could not initialize builder settings.'; return 1; }
  while :; do
    _v1160_choice=$(ui_menu 'Mini RootFS Builder' "$(v1160_header)" \
      guided 'Configure and build — guided workflow' \
      distro 'Distribution, release and architecture' \
      init 'Init system — OpenRC, SysVinit, runit or none' \
      packages 'Package presets and custom packages — Space selects' \
      location 'Target directory and package mirror' \
      identity 'Hostname, root password and regular user' \
      output 'Compression and archive output' \
      review 'Review complete configuration and package list' \
      templates 'Save or load a configuration template' \
      build 'Run preflight and build now' \
      back Back) || return 0
    case $_v1160_choice in
      guided) v1160_guided;; distro) v1160_distro_menu;; init) v1160_init_menu;; packages) v1160_packages_menu;;
      location) v1160_location_menu;; identity) v1160_identity_menu;; output) v1160_output_menu;;
      review) ui_text 'Mini RootFS configuration' "$(v1160_summary)\n\nResolved packages:\n$(v1160_packages | tr ' ' '\n')";;
      templates) v1160_template_menu;; build) v1160_build;; back) return 0;;
    esac
  done
}
