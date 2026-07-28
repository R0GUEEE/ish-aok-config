#!/bin/sh

MOUNT_STATE_DIR=$STATE_DIR/mounts
MOUNT_PROFILE_FILE=$MOUNT_STATE_DIR/profiles.conf
MOUNT_ROOTFS_PROFILE_FILE=$MOUNT_STATE_DIR/rootfs-profiles.conf
mkdir -p "$MOUNT_STATE_DIR" 2>/dev/null || true
[ -f "$MOUNT_PROFILE_FILE" ] || : >"$MOUNT_PROFILE_FILE"
[ -f "$MOUNT_ROOTFS_PROFILE_FILE" ] || : >"$MOUNT_ROOTFS_PROFILE_FILE"

mount_is_mounted(){ grep -qs " $1 " /proc/mounts 2>/dev/null; }
mount_escape_sed(){ printf '%s' "$1" | sed 's/[\/&]/\\&/g'; }
mount_safe_label(){ printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/_/g'; }

mount_table_report(){
  if have findmnt; then
    run_capture 'Mounted filesystems' findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS,SIZE,USED,AVAIL
  else
    run_capture 'Mounted filesystems' sh -c 'printf "%-30s %-30s %-12s %s\n" TARGET SOURCE TYPE OPTIONS; awk "{printf \"%-30s %-30s %-12s %s\\n\", \$2, \$1, \$3, \$4}" /proc/mounts'
  fi
}

mount_usage_report(){
  run_capture 'Mount usage' sh -c 'df -hT 2>/dev/null || df -h; printf "\nInodes:\n"; df -i'
}

mount_find_target(){
  p=$(ui_input 'Find mount' 'Path to inspect' "$CURRENT_HOME") || return
  if have findmnt; then run_capture 'Mount lookup' findmnt -T "$p"; else run_capture 'Mount lookup' sh -c "df -P '$p'; grep ' $p ' /proc/mounts 2>/dev/null || true"; fi
}

mount_standard_wizard(){
  need_root || return
  src=$(ui_input 'Mount filesystem' 'Source device, image, pseudo-filesystem name, or path' '') || return
  dst=$(ui_input 'Mount filesystem' 'Destination mountpoint' '/mnt') || return
  fstype=$(ui_input 'Mount filesystem' 'Filesystem type; blank for automatic detection' '') || return
  opts=$(ui_input 'Mount filesystem' 'Mount options; blank for defaults' '') || return
  ui_yesno 'Confirm mount' "Source: $src\nTarget: $dst\nType: ${fstype:-auto}\nOptions: ${opts:-defaults}" || return
  as_root mkdir -p "$dst" || return
  set -- mount
  [ -n "$fstype" ] && set -- "$@" -t "$fstype"
  [ -n "$opts" ] && set -- "$@" -o "$opts"
  set -- "$@" "$src" "$dst"
  run_capture 'Mounting filesystem' as_root "$@"
}

mount_bind_wizard(){
  need_root || return
  src=$(ui_input 'Bind mount' 'Source directory or file' '') || return
  [ -e "$src" ] || { ui_msg 'Bind mount' 'Source does not exist.'; return; }
  dst=$(ui_input 'Bind mount' 'Destination path' '/mnt/bind') || return
  mode=$(ui_radiolist 'Bind mount type' 'Choose bind behavior.' bind 'Bind only the selected path' on rbind 'Recursive bind including nested mounts' off) || return
  readonly=$(ui_yesno 'Read-only bind' 'Remount the bind destination read-only after mounting?'; printf '%s' $?)
  if [ -d "$src" ]; then as_root mkdir -p "$dst" || return; else as_root mkdir -p "$(dirname "$dst")" || return; [ -e "$dst" ] || as_root touch "$dst" || return; fi
  if [ "$mode" = rbind ]; then run_capture 'Creating recursive bind mount' as_root mount --rbind "$src" "$dst" || return; else run_capture 'Creating bind mount' as_root mount --bind "$src" "$dst" || return; fi
  [ "$readonly" -eq 0 ] && run_capture 'Remounting read-only' as_root mount -o remount,bind,ro "$dst" || true
}

mount_tmpfs_wizard(){
  need_root || return
  dst=$(ui_input 'tmpfs mount' 'Destination mountpoint' '/tmp') || return
  size=$(ui_input 'tmpfs mount' 'Maximum size, for example 128M; blank for kernel default' '128M') || return
  mode=$(ui_input 'tmpfs mount' 'Directory mode' '1777') || return
  extra=$(ui_input 'tmpfs mount' 'Additional options; blank for none' 'nosuid,nodev') || return
  opts="mode=$mode"
  [ -n "$size" ] && opts="$opts,size=$size"
  [ -n "$extra" ] && opts="$opts,$extra"
  as_root mkdir -p "$dst" || return
  run_capture 'Mounting tmpfs' as_root mount -t tmpfs -o "$opts" tmpfs "$dst"
}

mount_virtual_wizard(){
  need_root || return
  kind=$(ui_menu 'Virtual filesystem' 'Select a virtual filesystem to mount.' proc '/proc process filesystem' sys '/sys sysfs filesystem' devpts '/dev/pts pseudo-terminals' tmpfs '/run runtime tmpfs' devbind 'Bind host /dev' sysbind 'Recursive-bind host /sys' runbind 'Bind host /run') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  case $kind in
    proc) dst=$(ui_input proc 'Destination' '/proc') || return; as_root mkdir -p "$dst"; run_capture 'Mounting proc' as_root mount -t proc proc "$dst";;
    sys) dst=$(ui_input sysfs 'Destination' '/sys') || return; as_root mkdir -p "$dst"; run_capture 'Mounting sysfs' as_root mount -t sysfs sysfs "$dst";;
    devpts) dst=$(ui_input devpts 'Destination' '/dev/pts') || return; as_root mkdir -p "$dst"; run_capture 'Mounting devpts' as_root mount -t devpts -o 'gid=5,mode=620,ptmxmode=666' devpts "$dst";;
    tmpfs) dst=$(ui_input tmpfs 'Destination' '/run') || return; as_root mkdir -p "$dst"; run_capture 'Mounting runtime tmpfs' as_root mount -t tmpfs -o 'mode=755,nosuid,nodev' tmpfs "$dst";;
    devbind) dst=$(ui_input '/dev bind' 'Destination' '/mnt/rootfs/dev') || return; as_root mkdir -p "$dst"; run_capture 'Binding /dev' as_root mount --rbind /dev "$dst";;
    sysbind) dst=$(ui_input '/sys bind' 'Destination' '/mnt/rootfs/sys') || return; as_root mkdir -p "$dst"; run_capture 'Binding /sys' as_root mount --rbind /sys "$dst";;
    runbind) dst=$(ui_input '/run bind' 'Destination' '/mnt/rootfs/run') || return; as_root mkdir -p "$dst"; run_capture 'Binding /run' as_root mount --bind /run "$dst";;
  esac
}

mount_remount_wizard(){
  need_root || return
  dst=$(ui_input 'Remount filesystem' 'Mounted target' '/') || return
  mount_is_mounted "$dst" || { ui_msg Remount 'The exact target is not present in /proc/mounts.'; return; }
  mode=$(ui_menu Remount 'Choose new mode.' rw 'Read-write' ro 'Read-only' custom 'Custom remount options') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  case $mode in rw|ro) opts="remount,$mode";; custom) opts=$(ui_input Remount 'Options after remount,' 'rw') || return; opts="remount,$opts";; esac
  run_capture 'Remounting filesystem' as_root mount -o "$opts" "$dst"
}

mount_unmount_wizard(){
  need_root || return
  dst=$(ui_input 'Unmount filesystem' 'Exact target to unmount' '/mnt') || return
  mount_is_mounted "$dst" || { ui_msg Unmount 'The exact target is not currently mounted.'; return; }
  mode=$(ui_menu Unmount 'Choose unmount behavior.' normal 'Normal unmount' lazy 'Lazy detach' force 'Force where supported' recursive 'Recursive unmount where supported') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  case $mode in
    normal) run_capture 'Unmounting filesystem' as_root umount "$dst";;
    lazy) run_capture 'Lazy-unmounting filesystem' as_root umount -l "$dst";;
    force) run_capture 'Force-unmounting filesystem' as_root umount -f "$dst";;
    recursive) if umount --help 2>&1 | grep -q -- 'recursive'; then run_capture 'Recursively unmounting filesystem' as_root umount -R "$dst"; else ui_msg Unmount 'This umount implementation does not advertise recursive unmount support.'; fi;;
  esac
}

mount_busy_diagnostics(){
  dst=$(ui_input 'Busy mount diagnostics' 'Mounted target or directory' '/mnt') || return
  if have fuser; then run_capture 'Processes using mount' fuser -vm "$dst"
  elif have lsof; then run_capture 'Processes using mount' lsof +D "$dst"
  else ui_msg 'Busy mount diagnostics' 'Install psmisc for fuser or install lsof.'; fi
}

mount_kill_users(){
  need_root || return
  dst=$(ui_input 'Terminate mount users' 'Mounted target or directory' '/mnt') || return
  have fuser || { ui_msg Processes 'Install psmisc to provide fuser.'; return; }
  ui_yesno Processes "Terminate processes currently using $dst?" || return
  run_capture 'Terminating mount users' as_root fuser -km "$dst"
}

mount_stale_scan(){
  run_capture 'Mount consistency scan' sh -c '
    printf "Mount targets missing from filesystem:\n"
    awk "{print \$2}" /proc/mounts | while IFS= read -r p; do [ -e "$p" ] || printf "%s\n" "$p"; done
    printf "\nDuplicate targets:\n"
    awk "{print \$2}" /proc/mounts | sort | uniq -d
    printf "\nDeleted open files under mounts:\n"
    if command -v lsof >/dev/null 2>&1; then lsof +L1 2>/dev/null || true; else echo "lsof is not installed"; fi
  '
}

mount_profile_add(){
  scope=$1
  file=$MOUNT_PROFILE_FILE
  [ "$scope" = rootfs ] && file=$MOUNT_ROOTFS_PROFILE_FILE
  name=$(ui_input 'Save mount profile' 'Unique profile name' '') || return
  [ -n "$name" ] || return
  name=$(mount_safe_label "$name")
  kind=$(ui_menu 'Profile type' 'Select mount operation.' mount 'Normal filesystem mount' bind 'Bind mount' rbind 'Recursive bind mount' tmpfs 'tmpfs mount') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  src=$(ui_input 'Profile source' 'Source; use none for tmpfs' 'none') || return
  dst=$(ui_input 'Profile destination' "Destination${scope:+ relative to active rootfs when scope is rootfs}" '/mnt/data') || return
  fstype=$(ui_input 'Profile filesystem type' 'Type; blank for automatic' '') || return
  opts=$(ui_input 'Profile options' 'Comma-separated options; blank for defaults' '') || return
  tmp=$TMP_DIR/mount-profiles
  awk -F'|' -v n="$name" '$1!=n' "$file" >"$tmp" 2>/dev/null || : >"$tmp"
  printf '%s|%s|%s|%s|%s|%s\n' "$name" "$kind" "$src" "$dst" "$fstype" "$opts" >>"$tmp"
  cp "$tmp" "$file"
  ui_msg 'Mount profile' "Saved profile: $name"
}

mount_profile_list(){ scope=$1; file=$MOUNT_PROFILE_FILE; [ "$scope" = rootfs ] && file=$MOUNT_ROOTFS_PROFILE_FILE; [ -s "$file" ] && ui_text 'Mount profiles' "$(awk -F'|' '{printf "%-20s %-7s %-24s -> %-24s type=%s opts=%s\n",$1,$2,$3,$4,$5,$6}' "$file")" || ui_msg 'Mount profiles' 'No profiles have been saved.'; }

mount_profile_choose(){
  file=$1
  [ -s "$file" ] || return 1
  set --
  while IFS='|' read -r name kind src dst fstype opts; do [ -n "$name" ] && set -- "$@" "$name" "$kind: $src -> $dst"; done <"$file"
  ui_menu 'Select mount profile' 'Choose a saved profile.' "$@"
}

mount_profile_apply(){
  scope=$1; file=$MOUNT_PROFILE_FILE; prefix=''
  if [ "$scope" = rootfs ]; then file=$MOUNT_ROOTFS_PROFILE_FILE; prefix=$(active_rootfs); [ "$prefix" != / ] || { ui_msg RootFS 'Select a non-host active rootfs first.'; return; }; fi
  name=$(mount_profile_choose "$file") || return
  line=$(awk -F'|' -v n="$name" '$1==n{print;exit}' "$file")
  oldifs=$IFS; IFS='|'; set -- $line; IFS=$oldifs
  name=$1; kind=$2; src=$3; dst=$4; fstype=$5; opts=$6
  [ -n "$prefix" ] && dst="$prefix$dst"
  need_root || return
  as_root mkdir -p "$dst" || return
  case $kind in
    bind) run_capture "Applying mount profile $name" as_root mount --bind "$src" "$dst";;
    rbind) run_capture "Applying mount profile $name" as_root mount --rbind "$src" "$dst";;
    tmpfs) [ -n "$opts" ] && run_capture "Applying mount profile $name" as_root mount -t tmpfs -o "$opts" tmpfs "$dst" || run_capture "Applying mount profile $name" as_root mount -t tmpfs tmpfs "$dst";;
    mount)
      set -- mount
      [ -n "$fstype" ] && set -- "$@" -t "$fstype"
      [ -n "$opts" ] && set -- "$@" -o "$opts"
      set -- "$@" "$src" "$dst"
      run_capture "Applying mount profile $name" as_root "$@"
      ;;
  esac
}

mount_profile_remove(){
  scope=$1; file=$MOUNT_PROFILE_FILE; [ "$scope" = rootfs ] && file=$MOUNT_ROOTFS_PROFILE_FILE
  name=$(mount_profile_choose "$file") || return
  ui_yesno 'Remove mount profile' "Remove profile $name?" || return
  tmp=$TMP_DIR/mount-profiles
  awk -F'|' -v n="$name" '$1!=n' "$file" >"$tmp" && cp "$tmp" "$file"
}

mount_profile_script(){
  scope=$1; file=$MOUNT_PROFILE_FILE; prefix=''
  [ "$scope" = rootfs ] && { file=$MOUNT_ROOTFS_PROFILE_FILE; prefix=$(active_rootfs); }
  name=$(mount_profile_choose "$file") || return
  line=$(awk -F'|' -v n="$name" '$1==n{print;exit}' "$file")
  oldifs=$IFS; IFS='|'; set -- $line; IFS=$oldifs
  name=$1; kind=$2; src=$3; dst=$4; fstype=$5; opts=$6
  [ -n "$prefix" ] && [ "$prefix" != / ] && dst="$prefix$dst"
  cmd='mount'
  case $kind in bind) cmd="mount --bind '$src' '$dst'";; rbind) cmd="mount --rbind '$src' '$dst'";; tmpfs) cmd="mount -t tmpfs${opts:+ -o '$opts'} tmpfs '$dst'";; mount) cmd="mount${fstype:+ -t '$fstype'}${opts:+ -o '$opts'} '$src' '$dst'";; esac
  body="#!/bin/sh\nset -eu\nmkdir -p '$dst'\n$cmd"
  aok_write_script "mount-profile-$name" "$body"
}

mount_profiles_menu(){
  scope=${1:-host}
  while :; do
    c=$(ui_menu 'Mount profiles' "Scope: $scope" list 'List saved profiles' add 'Create or replace a profile' apply 'Apply a profile now' script 'Generate reusable mount script' remove 'Remove a profile' raw 'Open raw profile database' back Back) || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in list) mount_profile_list "$scope";; add) mount_profile_add "$scope";; apply) mount_profile_apply "$scope";; script) mount_profile_script "$scope";; remove) mount_profile_remove "$scope";; raw) [ "$scope" = rootfs ] && edit_file "$MOUNT_ROOTFS_PROFILE_FILE" || edit_file "$MOUNT_PROFILE_FILE";; back) return;; esac
  done
}

fstab_add_wizard(){
  need_root || return
  src=$(ui_input fstab 'Source device, UUID=, LABEL=, or path' '') || return
  dst=$(ui_input fstab 'Mountpoint' '/mnt/data') || return
  typ=$(ui_input fstab 'Filesystem type' 'auto') || return
  opts=$(ui_input fstab 'Options' 'defaults,nofail') || return
  dump=$(ui_input fstab 'Dump field' '0') || return
  pass=$(ui_input fstab 'Filesystem check pass' '0') || return
  line="$src $dst $typ $opts $dump $pass"
  ui_yesno fstab "Add this entry to /etc/fstab?\n\n$line" || return
  backup_file /etc/fstab
  as_root mkdir -p "$dst" || return
  printf '%s\n' "$line" | as_root tee -a /etc/fstab >/dev/null
}

fstab_menu(){
  while :; do c=$(ui_menu '/etc/fstab manager' 'Persistent host mounts. Use nofail for optional mounts.' show 'Show parsed fstab' add 'Add an entry with wizard' test 'Validate with mount -a --fake where available' mountall 'Mount all fstab entries' unmountall 'Unmount all fstab entries where supported' backup 'Back up fstab' edit 'Advanced raw edit' back Back) || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in
    show) run_capture fstab sh -c 'cat /etc/fstab 2>/dev/null || true';;
    add) fstab_add_wizard;;
    test) if mount --help 2>&1 | grep -q -- '--fake'; then run_capture 'Validating fstab' as_root mount -a --fake -v; else run_capture 'Checking fstab syntax' sh -c "awk 'NF && \$1 !~ /^#/ && NF < 4 {print \"Invalid line \" NR \": \" \$0; bad=1} END{exit bad}' /etc/fstab"; fi;;
    mountall) ui_yesno fstab 'Run mount -a now?' && run_capture 'Mounting fstab entries' as_root mount -a -v;;
    unmountall) if umount --help 2>&1 | grep -q -- '--all-targets'; then ui_yesno fstab 'Unmount filesystems listed in fstab?' && run_capture 'Unmounting fstab entries' as_root umount -a; else ui_msg fstab 'Bulk unmount is not exposed by this umount implementation. Unmount targets individually.'; fi;;
    backup) backup_file /etc/fstab; ui_msg fstab "Backup stored under $BACKUP_DIR";;
    edit) edit_file /etc/fstab;; back) return;;
  esac; done
}

mount_manager_menu(){
  while :; do c=$(ui_menu 'Mount management' 'Mount, inspect, save, diagnose, and safely detach filesystems.' table 'Detailed mount table' usage 'Filesystem usage and inodes' find 'Find the mount containing a path' mount 'Mount a filesystem or device' bind 'Create bind or recursive-bind mount' tmpfs 'Create tmpfs mount' virtual 'Mount proc, sysfs, devpts, /dev, or /run' remount 'Remount read-only, read-write, or custom' unmount 'Unmount a selected target' busy 'Show processes using a mount' kill 'Terminate processes using a mount' stale 'Scan for inconsistent or stale mounts' profiles 'Saved host mount profiles' rootprofiles 'Saved active-rootfs mount profiles' fstab 'Persistent /etc/fstab manager' chroot 'AOK chroot mount manager' back Back) || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in
    table) mount_table_report;; usage) mount_usage_report;; find) mount_find_target;; mount) mount_standard_wizard;; bind) mount_bind_wizard;; tmpfs) mount_tmpfs_wizard;; virtual) mount_virtual_wizard;; remount) mount_remount_wizard;; unmount) mount_unmount_wizard;; busy) mount_busy_diagnostics;; kill) mount_kill_users;; stale) mount_stale_scan;; profiles) mount_profiles_menu host;; rootprofiles) mount_profiles_menu rootfs;; fstab) fstab_menu;; chroot) aok_chroot_menu;; back) return;;
  esac; done
}
