#!/bin/sh

V72_OVERLAY_DIR=${V72_OVERLAY_DIR:-$AOK_STATE_DIR/overlays}
V72_MIGRATION_DIR=${V72_MIGRATION_DIR:-$AOK_STATE_DIR/migrations}
V72_AUTOMATION_DIR=${V72_AUTOMATION_DIR:-$AOK_STATE_DIR/automation}
mkdir -p "$V72_OVERLAY_DIR" "$V72_MIGRATION_DIR" "$V72_AUTOMATION_DIR"

v72_safe_name(){ printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '_' | sed 's/^_*//;s/_*$//'; }
v72_stamp(){ date +%Y%m%d-%H%M%S; }

# ---------- Overlay Studio ----------
overlay_list(){ find "$V72_OVERLAY_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort; }
overlay_meta(){ printf '%s/.overlay.conf' "$1"; }
overlay_get(){ f=$(overlay_meta "$1"); k=$2; [ -r "$f" ] && sed -n "s/^${k}=//p" "$f" | head -1; }
overlay_set(){ d=$1; k=$2; v=$3; f=$(overlay_meta "$d"); mkdir -p "$d/files"; if [ -f "$f" ]; then awk -F= -v k="$k" '$1!=k{print}' "$f" >"$f.tmp"; else : >"$f.tmp"; fi; printf '%s=%s\n' "$k" "$v" >>"$f.tmp"; mv "$f.tmp" "$f"; }
overlay_create(){
  n=$(ui_input 'Create overlay' 'Overlay name') || return
  n=$(v72_safe_name "$n"); [ -n "$n" ] || return
  d="$V72_OVERLAY_DIR/$n"; [ ! -e "$d" ] || { ui_msg Overlay 'An overlay with that name already exists.'; return; }
  mkdir -p "$d/files"
  overlay_set "$d" name "$n"; overlay_set "$d" enabled no; overlay_set "$d" priority 50; overlay_set "$d" dependencies ''; overlay_set "$d" description ''
  ui_msg Overlay "Created: $d"
}
overlay_select(){
  list=$(overlay_list); [ -n "$list" ] || { ui_msg Overlays 'No overlays exist.'; return 1; }
  set --; old=$IFS; IFS='\n'; for d in $list; do n=$(overlay_get "$d" name); [ -n "$n" ] || n=$(basename "$d"); st=$(overlay_get "$d" enabled); p=$(overlay_get "$d" priority); set -- "$@" "$d" "[$st] priority ${p:-50} - $n"; done; IFS=$old
  ui_menu 'Select overlay' 'Choose an overlay.' "$@"
}
overlay_validate(){
  d=$1; out=$TMP_DIR/overlay-validate; : >"$out"
  [ -d "$d/files" ] || echo 'ERROR missing files directory' >>"$out"
  p=$(overlay_get "$d" priority); case $p in ''|*[!0-9]*) echo 'ERROR priority must be numeric' >>"$out";; *) echo "OK priority=$p" >>"$out";; esac
  deps=$(overlay_get "$d" dependencies); for dep in $(printf '%s' "$deps" | tr ',' ' '); do [ -d "$V72_OVERLAY_DIR/$dep" ] && echo "OK dependency $dep" >>"$out" || echo "ERROR missing dependency $dep" >>"$out"; done
  find "$d/files" -type l 2>/dev/null | while IFS= read -r l; do target=$(readlink "$l"); case $target in /*) echo "WARN absolute symlink: ${l#$d/files} -> $target";; esac; done >>"$out"
  [ -s "$out" ] || echo 'OK overlay structure is valid' >"$out"; cat "$out"
}
overlay_conflicts(){
  d=$1; out=$TMP_DIR/overlay-conflicts; : >"$out"
  find "$d/files" -type f -o -type l 2>/dev/null | while IFS= read -r f; do rel=${f#"$d/files/"}; for other in $(overlay_list); do [ "$other" = "$d" ] && continue; [ -e "$other/files/$rel" ] && printf '%s\t%s\n' "$rel" "$(basename "$other")"; done; done | sort -u >"$out"
  [ -s "$out" ] && cat "$out" || echo 'No file conflicts detected.'
}
overlay_apply(){
  d=$1; r=$(active_rootfs); [ -d "$r" ] || return
  aok_confirm "Apply overlay $(basename "$d") to $r? Existing files may be replaced." || return
  backup="$AOK_STATE_DIR/overlay-backups/$(basename "$d")-$(v72_stamp)"; mkdir -p "$backup"
  (cd "$d/files" && find . -type f -o -type l) | while IFS= read -r rel; do rel=${rel#./}; [ -e "$r/$rel" ] && { mkdir -p "$backup/$(dirname "$rel")"; cp -a "$r/$rel" "$backup/$rel" 2>/dev/null || true; }; done
  cp -a "$d/files/." "$r/"
  printf '%s\t%s\t%s\n' "$(date -Iseconds 2>/dev/null || date)" "$d" "$backup" >>"$AOK_STATE_DIR/overlay-history.tsv"
  ui_msg Overlay "Applied overlay. Backup: $backup"
}
overlay_edit(){
  d=$1
  while :; do
    c=$(ui_menu 'Overlay details' "$(basename "$d")\nEnabled: $(overlay_get "$d" enabled)  Priority: $(overlay_get "$d" priority)" \
      toggle 'Enable or disable' priority 'Set priority' deps 'Set dependencies' description 'Edit description' files 'Open files directory in configured editor' validate 'Validate overlay' conflicts 'Detect conflicts' apply 'Apply to active rootfs' export 'Export overlay archive' delete 'Delete overlay') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      toggle) [ "$(overlay_get "$d" enabled)" = yes ] && overlay_set "$d" enabled no || overlay_set "$d" enabled yes;;
      priority) v=$(ui_input Priority 'Numeric priority; lower runs first' "$(overlay_get "$d" priority)") || continue; case $v in *[!0-9]*|'') ui_msg Priority 'Enter a number.';; *) overlay_set "$d" priority "$v";; esac;;
      deps) v=$(ui_input Dependencies 'Comma-separated overlay names' "$(overlay_get "$d" dependencies)") || continue; overlay_set "$d" dependencies "$v";;
      description) v=$(ui_input Description 'Overlay description' "$(overlay_get "$d" description)") || continue; overlay_set "$d" description "$v";;
      files) edit_file "$d/files/.overlay-files";;
      validate) ui_text Validation "$(overlay_validate "$d")";;
      conflicts) ui_text Conflicts "$(overlay_conflicts "$d")";;
      apply) overlay_apply "$d";;
      export) out="$V72_OVERLAY_DIR/$(basename "$d")-$(v72_stamp).tar.gz"; tar -C "$V72_OVERLAY_DIR" -czf "$out" "$(basename "$d")" && sha256sum "$out" >"$out.sha256"; ui_msg Export "$out";;
      delete) aok_confirm "Delete overlay $(basename "$d")?" && { rm -rf "$d"; return; };;
    esac
  done
}
overlay_studio_v72(){ while :; do c=$(ui_menu 'Overlay Studio' "Active rootfs: $(active_rootfs)" create 'Create overlay' browse 'Browse and manage overlays' order 'Show enabled application order' history 'View application history') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in create) overlay_create;; browse) d=$(overlay_select) || continue; overlay_edit "$d";; order) ui_text Order "$(for d in $(overlay_list); do [ "$(overlay_get "$d" enabled)" = yes ] && printf '%s\t%s\n' "$(overlay_get "$d" priority)" "$(basename "$d")"; done | sort -n)";; history) ui_text History "$(cat "$AOK_STATE_DIR/overlay-history.tsv" 2>/dev/null || echo 'No overlay applications recorded.')";; esac; done; }

# ---------- Migration Studio ----------
migration_audit(){
  r=$(active_rootfs); out="$V72_MIGRATION_DIR/audit-$(rootfs_id "$r")-$(v72_stamp).txt"
  { echo "iSH-AOK migration audit"; echo "rootfs=$r"; echo "distribution=$(aok_root_os "$r")"; echo "init=$(rootfs_detect_init "$r")"; echo "package_manager=$(rootfs_detect_pkgmgr "$r")"; echo; echo '[systemd references]'; grep -R -I -n -E 'systemctl|/run/systemd|systemd-' "$r/etc" "$r/usr/local" 2>/dev/null | head -200; echo; echo '[services]'; find "$r/etc/init.d" "$r/etc/runlevels" "$r/etc/systemd" -maxdepth 3 -type f 2>/dev/null | head -300; echo; echo '[repositories]'; find "$r/etc/apt" "$r/etc/apk" "$r/etc/yum.repos.d" -type f -maxdepth 3 2>/dev/null -exec sh -c 'echo --- $1; sed -n "1,120p" "$1"' sh {} \;; } >"$out"
  printf '%s' "$out"
}
migration_plan(){
  kind=$1; r=$(active_rootfs); out="$V72_MIGRATION_DIR/plan-${kind}-$(rootfs_id "$r")-$(v72_stamp).txt"
  audit=$(migration_audit)
  { echo "Migration plan: $kind"; echo "RootFS: $r"; echo "Audit: $audit"; echo; case $kind in debian-devuan) cat <<'P'
1. Create a verified snapshot and package manifest.
2. Disable Debian systemd-specific repositories and add matching Devuan merged repositories.
3. Install devuan-keyring, sysvinit-core, initscripts and elogind compatibility packages.
4. Remove or replace systemd-only packages after dependency review.
5. Rebuild init scripts, inittab, resolv.conf and SSH configuration.
6. Run package repair, health and compatibility checks.
P
;; ubuntu-devuan) cat <<'P'
1. Snapshot the rootfs and export package/repository manifests.
2. Audit Ubuntu-specific packages, PPAs, snaps and systemd units.
3. Replace repositories with a compatible Devuan suite only after package mapping review.
4. Install SysVinit and compatibility packages before removing systemd components.
5. Repair package database, init scripts, DNS, locale and SSH.
6. Validate boot assumptions and unresolved package transitions.
P
;; systemd-sysv) cat <<'P'
1. Inventory enabled systemd units and map them to SysV scripts.
2. Install sysvinit-core and initscripts while preserving rescue access.
3. Generate /etc/inittab and service runlevel links.
4. Replace systemctl calls in local scripts with service/invoke-rc.d wrappers.
5. Retain a rollback snapshot until health and compatibility checks pass.
P
;; systemd-openrc) cat <<'P'
1. Inventory systemd services, timers, tmpfiles and environment files.
2. Install OpenRC and create default runlevel links.
3. Translate unit dependencies and ExecStart commands into OpenRC scripts.
4. Replace systemd-only runtime assumptions and validate /run handling.
5. Retain a rollback snapshot until health checks pass.
P
;; esac; } >"$out"
  printf '%s' "$out"
}
migration_backup(){ r=$(active_rootfs); d="$V72_MIGRATION_DIR/backup-$(rootfs_id "$r")-$(v72_stamp)"; mkdir -p "$d"; cp -a "$r/etc/os-release" "$r/etc/apt" "$r/etc/init.d" "$r/etc/inittab" "$r/etc/systemd" "$d/" 2>/dev/null || true; rootfs_manifest "$r" "$d/manifest.txt"; tar -C "$d" -czf "$d.tar.gz" . && rm -rf "$d"; printf '%s' "$d.tar.gz"; }
migration_studio_v72(){
  while :; do
    c=$(ui_menu 'Migration Studio' "Active: $(active_rootfs)\nMigrations create plans and backups before any conversion." audit 'Run migration audit' debian 'Plan Debian to Devuan' ubuntu 'Plan Ubuntu to Devuan' sysv 'Plan systemd to SysVinit' openrc 'Plan systemd to OpenRC' backup 'Create migration backup' tools 'Open existing repository and init conversion tools') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in audit) f=$(migration_audit); ui_text Audit "$(cat "$f")";; debian) f=$(migration_plan debian-devuan); ui_text Plan "$(cat "$f")";; ubuntu) f=$(migration_plan ubuntu-devuan); ui_text Plan "$(cat "$f")";; sysv) f=$(migration_plan systemd-sysv); ui_text Plan "$(cat "$f")";; openrc) f=$(migration_plan systemd-openrc); ui_text Plan "$(cat "$f")";; backup) f=$(migration_backup); ui_msg Backup "$f";; tools) aok_repos_init_ssh_menu;; esac
  done
}

# ---------- Compatibility and Boot ----------
compatibility_deep_report_v72(){
  r=$(active_rootfs); out="$ROOTFS_REPORT_DIR/compatibility-deep-$(rootfs_id "$r")-$(v72_stamp).txt"
  { echo 'iSH-AOK deep compatibility report'; echo "rootfs=$r"; echo "os=$(aok_root_os "$r")"; echo "arch=$(aok_root_arch "$r")"; echo "init=$(rootfs_detect_init "$r")"; echo; echo '[ELF interpreters]'; find "$r/bin" "$r/sbin" "$r/usr/bin" "$r/usr/sbin" -type f -perm -111 2>/dev/null | head -300 | while IFS= read -r f; do file "$f" 2>/dev/null | grep -q ELF || continue; readelf -l "$f" 2>/dev/null | sed -n "s@.*Requesting program interpreter: \(.*\)]@${f#$r}: \1@p"; done | sort -u; echo; echo '[kernel/system assumptions]'; grep -R -I -n -E '/proc/sys|/sys/fs/cgroup|udevadm|modprobe|mount .*overlay|unshare|namespace|seccomp|fanotify|inotify' "$r/etc" "$r/usr/local" 2>/dev/null | head -300; echo; echo '[device assumptions]'; grep -R -I -n -E '/dev/(loop|fuse|kvm|net/tun|mapper|shm)' "$r/etc" "$r/usr/local" 2>/dev/null | head -200; echo; echo '[init assumptions]'; grep -R -I -n -E 'systemctl|journalctl|loginctl|hostnamectl|timedatectl' "$r/etc" "$r/usr/local" 2>/dev/null | head -300; echo; echo '[static emulators]'; find "$r/usr/bin" -maxdepth 1 -name 'qemu-*-static' -type f 2>/dev/null; } >"$out"
  printf '%s' "$out"
}
boot_service_inventory(){
  r=$(active_rootfs); out=$TMP_DIR/boot-services; : >"$out"
  if [ -d "$r/etc/rc.d" ] || [ -d "$r/etc/init.d" ]; then find "$r/etc/rc.d" "$r/etc/init.d" -maxdepth 2 -type f 2>/dev/null | sort >>"$out"; fi
  [ -d "$r/etc/runlevels" ] && find "$r/etc/runlevels" -maxdepth 2 -type l 2>/dev/null | sort >>"$out"
  [ -d "$r/etc/systemd/system" ] && find "$r/etc/systemd/system" -maxdepth 2 -type l 2>/dev/null | sort >>"$out"
  cat "$out"
}
boot_profile_report(){ r=$(active_rootfs); { echo "init=$(rootfs_detect_init "$r")"; echo; [ -f "$r/etc/inittab" ] && { echo '[inittab]'; sed -n '1,200p' "$r/etc/inittab"; }; echo; echo '[services]'; boot_service_inventory; }; }
boot_studio_v72(){ while :; do c=$(ui_menu 'Boot and Init Studio' "Active: $(active_rootfs)" report 'Boot and service report' inittab 'Edit /etc/inittab' services 'Open service manager' sysv 'Open SysVinit tools' compatibility 'Run deep compatibility report' startup 'Audit startup duration assumptions') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in report) ui_text Boot "$(boot_profile_report)";; inittab) edit_file "$(root_path /etc/inittab)";; services) services_menu 2>/dev/null || service_center;; sysv) init_system_menu;; compatibility) f=$(compatibility_deep_report_v72); ui_text Compatibility "$(cat "$f")";; startup) r=$(active_rootfs); ui_text Startup "$(grep -R -I -n -E 'sleep [0-9]+|timeout [0-9]+|wait' "$r/etc/init.d" "$r/etc/rc.local" 2>/dev/null | head -250)";; esac; done; }

# ---------- RootFS Diff ----------
rootfs_diff_advanced_v72(){
  a=$(active_rootfs); b=$(rootfs_select_registered) || return; [ "$a" != "$b" ] || { ui_msg Diff 'Select a different rootfs.'; return; }
  section=$(ui_menu 'Advanced RootFS Diff' "A: $a\nB: $b" summary 'Summary' packages 'Packages' users 'Users and groups' services 'Services and init' repositories 'Repositories' configs 'Configuration files' permissions 'Permission differences') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  out="$ROOTFS_REPORT_DIR/diff-${section}-$(rootfs_id "$a")-$(rootfs_id "$b")-$(v72_stamp).txt"
  case $section in
    summary) { echo "OS $(aok_root_os "$a") -> $(aok_root_os "$b")"; echo "ARCH $(aok_root_arch "$a") -> $(aok_root_arch "$b")"; echo "INIT $(rootfs_detect_init "$a") -> $(rootfs_detect_init "$b")"; echo "PKG $(rootfs_detect_pkgmgr "$a") -> $(rootfs_detect_pkgmgr "$b")"; echo "SIZE $(du -sh "$a" 2>/dev/null | awk '{print $1}') -> $(du -sh "$b" 2>/dev/null | awk '{print $1}')"; } >"$out";;
    packages) rootfs_manifest "$a" "$TMP_DIR/a.man"; rootfs_manifest "$b" "$TMP_DIR/b.man"; sed -n '/^\[packages\]/,/^\[services\]/p' "$TMP_DIR/a.man" | sort >"$TMP_DIR/a"; sed -n '/^\[packages\]/,/^\[services\]/p' "$TMP_DIR/b.man" | sort >"$TMP_DIR/b"; diff -u "$TMP_DIR/a" "$TMP_DIR/b" >"$out" || true;;
    users) { echo '[passwd]'; diff -u "$a/etc/passwd" "$b/etc/passwd" || true; echo '[group]'; diff -u "$a/etc/group" "$b/etc/group" || true; } >"$out";;
    services) { echo '[init]'; echo "$(rootfs_detect_init "$a") -> $(rootfs_detect_init "$b")"; diff -qr "$a/etc/init.d" "$b/etc/init.d" 2>/dev/null || true; diff -qr "$a/etc/runlevels" "$b/etc/runlevels" 2>/dev/null || true; } >"$out";;
    repositories) diff -ru "$a/etc/apt" "$b/etc/apt" >"$out" 2>&1 || true; diff -u "$a/etc/apk/repositories" "$b/etc/apk/repositories" >>"$out" 2>&1 || true;;
    configs) diff -qr "$a/etc" "$b/etc" >"$out" 2>&1 || true;;
    permissions) { (cd "$a" && find etc -xdev -printf '%m %u %g %p\n' 2>/dev/null | sort) >"$TMP_DIR/a"; (cd "$b" && find etc -xdev -printf '%m %u %g %p\n' 2>/dev/null | sort) >"$TMP_DIR/b"; diff -u "$TMP_DIR/a" "$TMP_DIR/b" || true; } >"$out";;
  esac
  ui_text 'Diff Results' "$(cat "$out")"
}

# ---------- Automation Scheduler ----------
automation_script_path(){ printf '%s/%s.sh' "$V72_AUTOMATION_DIR" "$(v72_safe_name "$1")"; }
automation_create_v72(){
  n=$(ui_input Automation 'Job name') || return; n=$(v72_safe_name "$n"); [ -n "$n" ] || return
  task=$(ui_menu Task 'Choose a maintenance task.' health 'Generate health report' compatibility 'Generate compatibility report' snapshot 'Create rootfs archive snapshot' cleanup 'Run safe cleanup' manifest 'Generate manifest') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  cron=$(ui_input Schedule 'Cron expression (example: 0 3 * * 0)' '0 3 * * 0') || return
  s=$(automation_script_path "$n"); root=$(active_rootfs)
  cat >"$s" <<EOS
#!/bin/sh
BASE=${BASE}
export AOK_ACTIVE_ROOTFS='${root}'
exec '${BASE}/ish-aok-config' --automation '${task}' '${root}'
EOS
  chmod +x "$s"; printf '%s\t%s\t%s\t%s\n' "$n" "$cron" "$task" "$s" >>"$V72_AUTOMATION_DIR/jobs.tsv"
  ui_msg Automation "Created job $n. Install into cron from the scheduler menu."
}
automation_install_cron_v72(){
  jobs="$V72_AUTOMATION_DIR/jobs.tsv"; [ -s "$jobs" ] || { ui_msg Automation 'No jobs defined.'; return; }
  block="$TMP_DIR/aok-cron"; awk -F '\t' '{print $2 " " $4 " # ish-aok:" $1}' "$jobs" >"$block"
  current="$TMP_DIR/crontab"; crontab -l >"$current" 2>/dev/null || :; sed '/# ish-aok:/d' "$current" >"$current.clean"; cat "$block" >>"$current.clean"; crontab "$current.clean" && ui_msg Automation 'Scheduled jobs installed in the current user crontab.'
}
automation_scheduler_v72(){ while :; do c=$(ui_menu 'Automation Scheduler' 'Create reusable maintenance jobs and optional cron entries.' list 'List jobs' create 'Create job' cron 'Install or refresh cron entries' scripts 'Browse generated scripts' remove 'Remove job') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in list) ui_text Jobs "$(column -t -s "$(printf '\t')" "$V72_AUTOMATION_DIR/jobs.tsv" 2>/dev/null || cat "$V72_AUTOMATION_DIR/jobs.tsv" 2>/dev/null || echo 'No jobs.')";; create) automation_create_v72;; cron) automation_install_cron_v72;; scripts) ui_text Scripts "$(find "$V72_AUTOMATION_DIR" -maxdepth 1 -type f -name '*.sh' -print)";; remove) n=$(ui_input Automation 'Job name to remove') || continue; n=$(v72_safe_name "$n"); awk -F '\t' -v n="$n" '$1!=n' "$V72_AUTOMATION_DIR/jobs.tsv" 2>/dev/null >"$TMP_DIR/jobs" && mv "$TMP_DIR/jobs" "$V72_AUTOMATION_DIR/jobs.tsv"; rm -f "$(automation_script_path "$n")";; esac; done; }

v72_engineering_menu(){
  while :; do
    c=$(ui_menu 'System Engineering' "Main > iSH-AOK > Workflow Edition > System Engineering\nActive: $(active_rootfs)" overlays 'Overlay Studio' migration 'Migration Studio' compatibility 'Deep compatibility analysis' boot 'Boot and Init Studio' diff 'Advanced RootFS diff' automation 'Automation scheduler') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in overlays) overlay_studio_v72;; migration) migration_studio_v72;; compatibility) f=$(compatibility_deep_report_v72); ui_text Compatibility "$(cat "$f")";; boot) boot_studio_v72;; diff) rootfs_diff_advanced_v72;; automation) automation_scheduler_v72;; esac
  done
}
