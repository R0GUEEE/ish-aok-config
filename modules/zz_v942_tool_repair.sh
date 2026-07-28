#!/bin/sh
# v9.4.2 runtime selector and tool audit repairs.

v942_destination_is_auto(){ [ "$(v87_profile_get "$V87_BUILD_PROFILE" DEST_AUTO)" != no ]; }
v942_set_auto_destination(){
  d=$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO); r=$(v87_profile_get "$V87_BUILD_PROFILE" RELEASE); a=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH)
  v87_profile_set "$V87_BUILD_PROFILE" DEST "$(rootfs_location_default "$d" "$r" "$a")"
  v87_profile_set "$V87_BUILD_PROFILE" DEST_AUTO yes
}

v92_profile_location_select(){
  v87_profile_defaults
  d=$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO); r=$(v87_profile_get "$V87_BUILD_PROFILE" RELEASE); a=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH)
  label=$(printf '%s-%s-%s' "${d:-rootfs}" "${r:-current}" "${a:-arm64}" | tr ' /' '--')
  current=$(v87_profile_get "$V87_BUILD_PROFILE" DEST); [ -n "$current" ] || current=$(rootfs_location_default "$d" "$r" "$a")
  p=$(rootfs_location_select "$current" "$label") || return
  rootfs_location_validate "$p" >/dev/null 2>&1 || { ui_msg 'Build profile' "Rejected invalid RootFS destination:\n$p"; return 1; }
  v87_profile_set "$V87_BUILD_PROFILE" DEST "$p" || { ui_msg 'Build profile' 'Could not save the selected destination.'; return 1; }
  v87_profile_set "$V87_BUILD_PROFILE" DEST_AUTO no
  saved=$(v87_profile_get "$V87_BUILD_PROFILE" DEST)
  [ "$saved" = "$p" ] || { ui_msg 'Build profile' "Destination save verification failed.\nSelected: $p\nSaved: $saved"; return 1; }
  ui_msg 'Build profile' "RootFS destination set to:\n$p"
}

v87_profile_choose_distro(){
  cur=$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO); [ -n "$cur" ] || cur=devuan
  d=$(ui_radiolist 'Build profile: Distribution' 'Choose a distribution preset.' \
    devuan 'Devuan GNU/Linux' "$(v87_choice_state "$cur" devuan)" debian 'Debian GNU/Linux' "$(v87_choice_state "$cur" debian)" ubuntu 'Ubuntu' "$(v87_choice_state "$cur" ubuntu)" alpine 'Alpine Linux' "$(v87_choice_state "$cur" alpine)" arch 'Arch Linux' "$(v87_choice_state "$cur" arch)" void 'Void Linux' "$(v87_choice_state "$cur" void)" gentoo 'Gentoo stage3' "$(v87_choice_state "$cur" gentoo)" fedora 'Fedora/Ultramarine' "$(v87_choice_state "$cur" fedora)") || return
  case $d in devuan) rel=excalibur; boot=debootstrap; init=sysvinit; mirror=https://deb.devuan.org/merged;; debian) rel=trixie; boot=debootstrap; init=sysvinit; mirror=https://deb.debian.org/debian;; ubuntu) rel=noble; boot=debootstrap; init=sysvinit; mirror=https://ports.ubuntu.com/ubuntu-ports;; alpine) rel=edge; boot=apk; init=openrc; mirror=https://dl-cdn.alpinelinux.org/alpine;; arch) rel=rolling; boot=pacstrap; init=none; mirror=;; void) rel=current; boot=xbps; init=runit; mirror=https://repo-default.voidlinux.org/current;; gentoo) rel=current; boot=stage3; init=openrc; mirror=;; fedora) rel=43; boot=dnf; init=sysvinit; mirror=;; esac
  v87_profile_set "$V87_BUILD_PROFILE" DISTRO "$d"; v87_profile_set "$V87_BUILD_PROFILE" RELEASE "$rel"; v87_profile_set "$V87_BUILD_PROFILE" BOOTSTRAP "$boot"; v87_profile_set "$V87_BUILD_PROFILE" INIT "$init"; v87_profile_set "$V87_BUILD_PROFILE" MIRROR "$mirror"
  v942_destination_is_auto && v942_set_auto_destination
}

v87_profile_choose_arch(){
  cur=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH); [ -n "$cur" ] || cur=arm64
  a=$(ui_radiolist 'Build profile: Architecture' 'Select the RootFS architecture supported by iSH-AOK.' arm64 'ARM64 / AArch64' "$(v87_choice_state "$cur" arm64)" i386 '32-bit x86' "$(v87_choice_state "$cur" i386)" amd64 '64-bit x86' "$(v87_choice_state "$cur" amd64)" riscv64 '64-bit RISC-V' "$(v87_choice_state "$cur" riscv64)") || return
  v87_profile_set "$V87_BUILD_PROFILE" ARCH "$a"
  v942_destination_is_auto && v942_set_auto_destination
}

v942_tool_audit_report(){
  printf 'iSH-AOK Config 9.4.2 — Tool Audit\n\n'
  printf '%-22s %-10s %s\n' TOOL STATUS PURPOSE
  for spec in 'dialog:TUI menus' 'whiptail:TUI fallback' 'tar:RootFS archives' 'gzip:gzip artifacts' 'xz:xz artifacts' 'zstd:zstd artifacts' 'curl:remote downloads' 'wget:remote downloads' 'rsync:directory import' 'chroot:RootFS entry' 'mount:mount manager' 'debootstrap:Debian-family builder' 'mmdebstrap:Debian-family builder' 'apk:Alpine builder' 'pacstrap:Arch builder' 'dnf:Fedora builder' 'xbps-install:Void builder' 'git:plugin repositories'; do
    tool=${spec%%:*}; purpose=${spec#*:}; if have "$tool"; then status=available; else status=missing; fi
    printf '%-22s %-10s %s\n' "$tool" "$status" "$purpose"
  done
  printf '\nUI mode: %s\nActive destination: %s\n' "$UI" "$(v87_profile_get "$V87_BUILD_PROFILE" DEST)"
}

v942_tool_audit_menu(){
  while :; do c=$(ui_menu 'Tool and Selector Audit' 'Check runtime dependencies and selector state.' report 'View tool availability report' destination 'Test and set RootFS destination' validate 'Validate active build profile' capabilities 'Builder capability report') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in report) ui_text 'Tool audit' "$(v942_tool_audit_report)";; destination) v92_profile_location_select;; validate) v87_profile_validate;; capabilities) ui_text 'Builder capabilities' "$(v94_builder_capability_report)";; esac; done
}

v942_tools_report(){ v942_tool_audit_report; }
command -v command_register >/dev/null 2>&1 && command_register tool_audit 'Tool and Selector Audit' System v942_tool_audit_menu 'Audit runtime tools and verify RootFS destination selection'
