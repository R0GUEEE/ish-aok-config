#!/bin/sh
aok_dashboard(){
  r=$(active_rootfs); os=$(aok_root_os "$r"); arch=$(aok_root_arch "$r");
  mounts=$(grep -c " $r/\| $r " /proc/mounts 2>/dev/null || echo 0)
  state=unknown; for f in "$r/opt/AOK/deploy_state" "$r/etc/aok/deploy_state" "$r/deploy_state"; do [ -r "$f" ] && state=$(cat "$f"); done
  ui_text 'AOK dashboard' "Active rootfs: $r\nDistribution: $os\nArchitecture: $arch\nRelated mounts: $mounts\nBuild state: $state\nAOK detected: $AOK_DETECTED\nHost: $DISTRO_ID / $ARCH / $INIT_SYSTEM\nState directory: $AOK_STATE_DIR"
}
aok_environment_report(){
  out=$(aok_report_file aok-environment)
  { echo 'iSH-AOK environment report'; date; echo; echo "Active rootfs: $(active_rootfs)"; echo "AOK detected: $AOK_DETECTED"; echo "Host distro: $DISTRO_ID"; echo "Architecture: $ARCH"; echo "Package manager: $PKG_MGR"; echo "Init: $INIT_SYSTEM"; echo; echo 'AOK paths:'; ls -ld /AOK /opt/AOK /AOK/persist /opt/AOK/persist 2>&1; echo; echo 'aokfs mounts:'; grep -E 'aokfs|/AOK|/opt/AOK' /proc/mounts 2>/dev/null; echo; echo 'Capabilities:'; for x in chroot mount umount debootstrap apk pacstrap dnf xbps-install qemu-aarch64 qemu-x86_64 file readelf tar rsync git shellcheck; do command -v "$x" 2>/dev/null || echo "missing: $x"; done; echo; echo 'Limits:'; ulimit -a 2>&1; } >"$out"
  [ "${AOK_REPORT_QUIET:-no}" = yes ] || ui_text Environment "$(cat "$out")"
}
aok_context_menu(){ while :; do c=$(ui_menu 'AOK dashboard & context' "Active: $(active_rootfs)" dashboard 'Show dashboard' select 'Select active rootfs' rescan 'Rescan discovered rootfs instances' environment 'Environment and capability report' paths 'Inspect AOK paths' mounts 'Inspect aokfs mounts' clear 'Reset active rootfs to host') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in dashboard) aok_dashboard;; select) aok_select_root;; rescan) aok_find_roots >"$REPORT_DIR/aok-roots.txt"; ui_text RootFS "$(cat "$REPORT_DIR/aok-roots.txt")";; environment) aok_environment_report;; paths) run_capture Paths sh -c 'ls -la /AOK /opt/AOK /AOK/persist /opt/AOK/persist 2>&1';; mounts) ui_text Mounts "$(grep -E 'aokfs|/AOK|/opt/AOK' /proc/mounts 2>/dev/null)";; clear) set_active_rootfs /;; esac; done; }
