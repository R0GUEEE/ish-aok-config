#!/bin/sh

v71_breadcrumb(){ printf 'Main > iSH-AOK > %s' "$1"; }

rootfs_registry_select_ui(){
  selected=$(rootfs_select_registered) || return 1
  [ -d "$selected" ] || { ui_msg RootFS "Selected RootFS is unavailable: $selected"; return 1; }
  set_active_rootfs "$selected" || return 1
  rootfs_registry_refresh "$selected" >/dev/null 2>&1 || true
  command -v v90_context_set >/dev/null 2>&1 && v90_context_set rootfs "$selected" || true
  command -v activity_add >/dev/null 2>&1 && activity_add rootfs "Selected $selected" || true
  ui_msg RootFS "Active RootFS:\n$selected"
}

rootfs_registry_browser(){
  while :; do
    c=$(ui_menu 'RootFS Registry' "$(v71_breadcrumb 'Registry')\nActive: $(active_rootfs)" \
      select 'Select and activate a registered RootFS' list 'View registered RootFS table' \
      search 'Search labels, tags, distro or architecture' favorite 'Toggle favorite for active rootfs' \
      refresh 'Refresh active rootfs metadata' details 'Show complete active metadata') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      select) rootfs_registry_select_ui;;
      list) ui_text 'RootFS Registry' "$(rootfs_registry_table | awk -F '\t' '{printf "%-24s %-12s %-10s %-10s %s\n",$2,$3,$4,$5,$1}')";;
      search) q=$(ui_input Search 'Search registry') || continue; hits=$(rootfs_registry_search "$q"); [ -n "$hits" ] && ui_text Results "$hits" || ui_msg Search 'No matching root filesystems.';;
      favorite) r=$(active_rootfs); rootfs_registry_refresh "$r"; cur=$(rootfs_meta_get "$r" favorite); [ "$cur" = yes ] && n=no || n=yes; rootfs_set_meta "$r" favorite "$n"; ui_msg Favorite "Favorite: $n";;
      refresh) rootfs_registry_refresh "$(active_rootfs)"; ui_msg Registry 'Metadata refreshed.';;
      details) r=$(active_rootfs); rootfs_registry_refresh "$r"; ui_text Metadata "$(cat "$(rootfs_meta_file "$r")")";;
    esac
  done
}

rootfs_global_search(){
  q=$(ui_input 'Global RootFS Search' 'Package, service, config, file, user, hostname, repository or plugin name') || return
  [ -n "$q" ] || return
  out="$ROOTFS_REPORT_DIR/global-search-$(date +%Y%m%d-%H%M%S).txt"
  : >"$out"
  rootfs_list | while IFS= read -r r; do
    [ -n "$r" ] || continue
    echo "===== $r =====" >>"$out"
    find "$r/etc" "$r/usr" "$r/opt" "$r/home" -xdev \( -type f -o -type l \) -iname "*$q*" 2>/dev/null | head -80 >>"$out"
    grep -R -I -n -m 2 -- "$q" "$r/etc/passwd" "$r/etc/group" "$r/etc/hostname" "$r/etc/apt" "$r/etc/apk" "$r/etc/pacman.conf" 2>/dev/null | head -80 >>"$out"
    echo >>"$out"
  done
  ui_text 'Global Search Results' "$(cat "$out")"
}

rootfs_health_interactive(){
  r=$(active_rootfs)
  while :; do
    out=$(rootfs_health_report)
    score=$(sed -n 's/^Health score: //p' "$out" | head -1)
    c=$(ui_menu 'Interactive Health Dashboard' "$(v71_breadcrumb 'Health')\nScore: ${score:-unknown}" \
      summary 'View complete health summary' dns 'DNS status and repair' packages 'Package manager status and repair' \
      shell 'Shell status and repair' permissions 'Permissions and integrity tools' mounts 'Runtime directories and mounts' refresh 'Refresh score') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      summary) ui_text Health "$(cat "$out")";;
      dns) [ -s "$r/etc/resolv.conf" ] && ui_text DNS "$(cat "$r/etc/resolv.conf")" || { ui_msg DNS 'resolv.conf is missing or empty.'; aok_confirm 'Repair DNS now?' && repair_dns; };;
      packages) ui_text Packages "Manager: $(rootfs_detect_pkgmgr "$r")"; aok_confirm 'Open package repair tools?' && aok_arch_packages_menu;;
      shell) ui_text Shell "Root shell: $(rootfs_detect_shell "$r")\n/bin/sh: $(ls -l "$r/bin/sh" 2>/dev/null)"; aok_confirm 'Repair /bin/sh if needed?' && repair_shells;;
      permissions) aok_advanced_tools_menu;;
      mounts) ui_text Mounts "$(for d in dev dev/pts proc sys run tmp; do [ -d "$r/$d" ] && echo "OK $d" || echo "MISSING $d"; done)"; aok_confirm 'Create missing runtime directories?' && repair_runtime_dirs;;
      refresh) :;;
    esac
  done
}

rootfs_diff_viewer(){
  a=$(active_rootfs); b=$(rootfs_select_registered) || return; [ "$a" != "$b" ] || { ui_msg Diff 'Choose a different rootfs.'; return; }
  out="$ROOTFS_REPORT_DIR/diff-view-$(rootfs_id "$a")-$(rootfs_id "$b")-$(date +%Y%m%d-%H%M%S).txt"
  { echo "A=$a"; echo "B=$b"; echo; echo '[metadata]'; echo "OS: $(aok_root_os "$a") -> $(aok_root_os "$b")"; echo "ARCH: $(aok_root_arch "$a") -> $(aok_root_arch "$b")"; echo "INIT: $(rootfs_detect_init "$a") -> $(rootfs_detect_init "$b")"; echo; echo '[packages]';
    ta="$TMP_DIR/pkg-a"; tb="$TMP_DIR/pkg-b"; rootfs_manifest "$a" "$ta"; rootfs_manifest "$b" "$tb"; sed -n '/^\[packages\]/,/^\[services\]/p' "$ta" | sort >"$ta.s"; sed -n '/^\[packages\]/,/^\[services\]/p' "$tb" | sort >"$tb.s"; diff -u "$ta.s" "$tb.s" 2>/dev/null | head -300;
    echo; echo '[configuration]'; diff -qr "$a/etc" "$b/etc" 2>/dev/null | head -300;
  } >"$out"
  ui_text 'RootFS Diff Viewer' "$(cat "$out")"
}

rootfs_report_generate(){
  parts=$(ui_checklist 'Generate Report' 'Select sections.' health Health on compatibility Compatibility on manifest 'Packages and services' on optimization 'Disk and optimization' on metadata 'Registry metadata' on) || return
  fmt=$(ui_menu 'Report Format' 'Choose output format.' text 'Plain text' md Markdown json JSON html HTML) || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  r=$(active_rootfs); base="$ROOTFS_REPORT_DIR/report-$(rootfs_id "$r")-$(date +%Y%m%d-%H%M%S)"; raw="$base.raw"; : >"$raw"
  for p in $parts; do case $p in health) x=$(rootfs_health_report); cat "$x" >>"$raw";; compatibility) x=$(rootfs_compatibility_report); cat "$x" >>"$raw";; manifest) rootfs_manifest "$r" "$TMP_DIR/manifest"; cat "$TMP_DIR/manifest" >>"$raw";; optimization) x=$(rootfs_optimization_report); cat "$x" >>"$raw";; metadata) cat "$(rootfs_meta_file "$r")" >>"$raw";; esac; printf '\n\n' >>"$raw"; done
  case $fmt in
    text) out=$base.txt; cp "$raw" "$out";;
    md) out=$base.md; { echo "# iSH-AOK RootFS Report"; echo; echo '```text'; cat "$raw"; echo '```'; } >"$out";;
    json) out=$base.json; awk 'BEGIN{print "{\"report\": ["} {gsub(/\\/,"\\\\");gsub(/\"/,"\\\""); printf "%s\"%s\"", (NR>1?",":""), $0} END{print "]}"}' "$raw" >"$out";;
    html) out=$base.html; { echo '<!doctype html><meta charset="utf-8"><title>iSH-AOK Report</title><pre>'; sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' "$raw"; echo '</pre>'; } >"$out";;
  esac
  rm -f "$raw"; ui_msg Report "Generated:\n$out"
}

rootfs_snapshot_browser(){
  dir=${AOK_SNAPSHOT_DIR:-$AOK_STATE_DIR/snapshots}; mkdir -p "$dir"
  files=$(find "$dir" -maxdepth 1 -type f \( -name '*.tar' -o -name '*.tar.gz' -o -name '*.tar.xz' \) 2>/dev/null | sort -r)
  [ -n "$files" ] || { ui_msg Snapshots 'No snapshot archives found.'; return; }
  set --; oldifs=$IFS; IFS='\n'; for f in $files; do set -- "$@" "$f" "$(basename "$f")"; done; IFS=$oldifs
  f=$(ui_menu 'Snapshot Browser' 'Choose a snapshot archive.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  c=$(ui_menu 'Snapshot Actions' "Selected: $(basename "$f")" details 'View archive details' verify 'Verify checksum' rename 'Rename snapshot' duplicate 'Duplicate snapshot' export 'Copy snapshot elsewhere' delete 'Delete snapshot') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  case $c in
    details) ui_text Snapshot "Path: $f\nSize: $(du -h "$f" 2>/dev/null | awk '{print $1}')\nModified: $(ls -l "$f" 2>/dev/null)";;
    verify) [ -f "$f.sha256" ] && (cd "$(dirname "$f")" && sha256sum -c "$(basename "$f.sha256")") | ui_text Verify "$(cat)" || ui_msg Verify 'No checksum sidecar found.';;
    rename) n=$(ui_input Rename 'New filename' "$(basename "$f")") || return; mv "$f" "$(dirname "$f")/$n";;
    duplicate) cp -a "$f" "$f.copy";;
    export) d=$(ui_input Export 'Destination directory') || return; mkdir -p "$d" && cp -a "$f" "$d/";;
    delete) aok_confirm "Delete $f?" && rm -f "$f" "$f.sha256";;
  esac
}

rootfs_package_native(){
  r=$(active_rootfs); pm=$(rootfs_detect_pkgmgr "$r")
  c=$(ui_menu 'Native Package Studio' "Manager: $pm\nActive: $r" search 'Search packages' info 'Package information' install 'Install package' remove 'Remove package' update 'Refresh indexes' upgrade 'Upgrade packages' orphans 'List orphan packages') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  pkg=''; case $c in search|info|install|remove) pkg=$(ui_input Packages 'Package name or search term') || return;; esac
  case $pm:$c in
    apt-get:search) as_root chroot "$r" apt-cache search "$pkg" 2>&1 | ui_text Packages "$(cat)";; apt-get:info) as_root chroot "$r" apt-cache show "$pkg" 2>&1 | ui_text Package "$(cat)";; apt-get:install) as_root chroot "$r" apt-get install "$pkg";; apt-get:remove) as_root chroot "$r" apt-get remove "$pkg";; apt-get:update) as_root chroot "$r" apt-get update;; apt-get:upgrade) as_root chroot "$r" apt-get upgrade;; apt-get:orphans) as_root chroot "$r" sh -c 'command -v deborphan >/dev/null && deborphan || apt-mark showauto';;
    apk:search) as_root chroot "$r" apk search "$pkg";; apk:info) as_root chroot "$r" apk info -a "$pkg";; apk:install) as_root chroot "$r" apk add "$pkg";; apk:remove) as_root chroot "$r" apk del "$pkg";; apk:update) as_root chroot "$r" apk update;; apk:upgrade) as_root chroot "$r" apk upgrade;; apk:orphans) as_root chroot "$r" apk info -r;;
    pacman:search) as_root chroot "$r" pacman -Ss "$pkg";; pacman:info) as_root chroot "$r" pacman -Si "$pkg";; pacman:install) as_root chroot "$r" pacman -S "$pkg";; pacman:remove) as_root chroot "$r" pacman -Rns "$pkg";; pacman:update|pacman:upgrade) as_root chroot "$r" pacman -Syu;; pacman:orphans) as_root chroot "$r" pacman -Qtdq;;
    xbps-install:search) as_root chroot "$r" xbps-query -Rs "$pkg";; xbps-install:info) as_root chroot "$r" xbps-query -RS "$pkg";; xbps-install:install) as_root chroot "$r" xbps-install "$pkg";; xbps-install:remove) as_root chroot "$r" xbps-remove -R "$pkg";; xbps-install:update) as_root chroot "$r" xbps-install -S;; xbps-install:upgrade) as_root chroot "$r" xbps-install -Su;; xbps-install:orphans) as_root chroot "$r" xbps-query -O;;
    dnf:search) as_root chroot "$r" dnf search "$pkg";; dnf:info) as_root chroot "$r" dnf info "$pkg";; dnf:install) as_root chroot "$r" dnf install "$pkg";; dnf:remove) as_root chroot "$r" dnf remove "$pkg";; dnf:update|dnf:upgrade) as_root chroot "$r" dnf upgrade;; dnf:orphans) as_root chroot "$r" dnf repoquery --unneeded;;
    emerge:search) as_root chroot "$r" emerge --search "$pkg";; emerge:info) as_root chroot "$r" emerge --info "$pkg";; emerge:install) as_root chroot "$r" emerge "$pkg";; emerge:remove) as_root chroot "$r" emerge --unmerge "$pkg";; emerge:update|emerge:upgrade) as_root chroot "$r" emerge --sync;; emerge:orphans) as_root chroot "$r" emerge --depclean --pretend;;
    *) ui_msg Packages "Unsupported operation for package manager: $pm";;
  esac
}

rootfs_automation_profiles(){
  c=$(ui_menu 'Automation Profiles' 'Run a multi-step workflow.' developer 'Developer rootfs readiness' minimal 'Minimal rootfs cleanup' builder 'Builder readiness' server 'Server readiness' portable 'Portable low-memory profile') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  case $c in
    developer) repair_runtime_dirs; repair_shells; rootfs_registry_refresh "$(active_rootfs)"; rootfs_manager_manifest;;
    minimal) rootfs_safe_cleanup; rootfs_optimization_report >/dev/null;;
    builder) repair_runtime_dirs; rootfs_health_report >/dev/null; rootfs_compatibility_report >/dev/null;;
    server) repair_runtime_dirs; [ -s "$(root_path /etc/resolv.conf)" ] || repair_dns; rootfs_health_report >/dev/null;;
    portable) rootfs_safe_cleanup; rootfs_registry_refresh "$(active_rootfs)";;
  esac
  ui_msg Automation 'Profile completed.'
}

build_queue_manager_v71(){
  qf="$AOK_STATE_DIR/build-queue.tsv"; touch "$qf"
  while :; do
    c=$(ui_menu 'Build Queue Manager' "Queued jobs: $(wc -l <"$qf" | tr -d ' ')" list 'List queued builds' add 'Add build recipe' duplicate 'Duplicate queue entry' delete 'Delete queue entry' clear 'Clear queue' run 'Run queue using existing builder') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      list) ui_text 'Build Queue' "$(nl -ba "$qf")";;
      add) name=$(ui_input Queue 'Recipe or profile name') || continue; arch=$(ui_input Queue 'Architecture' arm64) || continue; printf '%s\t%s\tpending\n' "$name" "$arch" >>"$qf";;
      duplicate) n=$(ui_input Queue 'Line number to duplicate') || continue; sed -n "${n}p" "$qf" >>"$qf";;
      delete) n=$(ui_input Queue 'Line number to delete') || continue; awk -v n="$n" 'NR!=n' "$qf" >"$qf.tmp" && mv "$qf.tmp" "$qf";;
      clear) aok_confirm 'Clear the build queue?' && : >"$qf";;
      run) ui_msg Queue 'Queue entries are retained as reproducible plans; each entry opens Builder Studio for execution.'; aok_builder_studio;;
    esac
  done
}

aok_v71_workflows_menu(){
  while :; do
    c=$(ui_menu 'iSH-AOK Workflow Edition' "$(v71_breadcrumb 'Workflow Edition')\nActive: $(active_rootfs)" \
      registry 'RootFS registry and favorites' packages 'Native package studio' \
      snapshots 'Snapshot browser' diff 'RootFS diff viewer' search 'Global RootFS search' reports 'Report generator' \
      queue 'Build queue manager' automation 'Automation profiles' engineering 'System engineering tools') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in registry) rootfs_registry_browser;; packages) rootfs_package_native;; snapshots) rootfs_snapshot_browser;; diff) rootfs_diff_viewer;; search) rootfs_global_search;; reports) rootfs_report_generate;; queue) build_queue_manager_v71;; automation) rootfs_automation_profiles;; engineering) v72_engineering_menu;; esac
  done
}
