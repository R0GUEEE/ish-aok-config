#!/bin/sh
# v9.5.1: package or chroot any RootFS directory without prior registration.

V951_ARTIFACT_DIR=${V951_ARTIFACT_DIR:-/AOK/build-artifacts}

v951_path_canonical(){
  [ -d "$1" ] || return 1
  (CDPATH= cd -P -- "$1" 2>/dev/null && pwd)
}

v951_choose_rootfs_directory(){
  title=${1:-'Select RootFS directory'}
  initial=${2:-$(active_rootfs 2>/dev/null || printf '/')}
  while :; do
    choice=$(ui_menu "$title" "Current path: $initial" path 'Enter an absolute directory path' browse 'Browse the filesystem' registered 'Choose a registered RootFS' recent 'Choose a recently used external RootFS' back Back) || {
      rc=$?
      [ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return "$rc"
      return "$rc"
    }
    case $choice in
      path)
        p=$(ui_input "$title" 'Absolute path to an existing RootFS directory' "$initial") || continue
        ;;
      browse)
        p=$(rootfs_anywhere_directory_browser "$initial") || continue
        [ -n "$p" ] || continue
        ;;
      registered)
        p=$(rootfs_select_registered) || continue
        ;;
      recent)
        p=$(rootfs_anywhere_recent_select) || continue
        ;;
    esac
    p=$(v951_path_canonical "$p") || { ui_msg RootFS "Directory not found or inaccessible:\n${p:-}"; continue; }
    printf '%s' "$p"
    return 0
  done
}

v951_safe_archive_name(){
  printf '%s' "$1" | sed 's#[^A-Za-z0-9._-]#-#g; s/^-*//; s/-*$//'
}

v951_package_rootfs_directory(){
  src=$(v951_choose_rootfs_directory 'Package RootFS directory') || {
    rc=$?; [ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$rc";
  }
  rootfs_anywhere_looks_valid "$src" || ui_yesno Package "The directory does not look like a complete Linux RootFS:\n\n$src\n\nPackage it anyway?" || return 0

  format=$(ui_menu 'RootFS archive format' 'Choose compression for the tarball.' zstd 'tar.zst — compact and fast when zstd is installed' gzip 'tar.gz — broadly compatible' xz 'tar.xz — smaller but slower' tar 'tar — uncompressed') || {
    rc=$?; [ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$rc";
  }
  case $format in
    zstd) have zstd || { ui_msg Package 'zstd is not installed.'; return 1; }; ext=tar.zst;;
    gzip) have gzip || { ui_msg Package 'gzip is not installed.'; return 1; }; ext=tar.gz;;
    xz) have xz || { ui_msg Package 'xz is not installed.'; return 1; }; ext=tar.xz;;
    tar) ext=tar;;
  esac

  base=$(v951_safe_archive_name "$(basename "$src")")
  [ -n "$base" ] || base=rootfs
  stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || date +%s)
  default_dir=$V951_ARTIFACT_DIR
  [ -d "$default_dir" ] || default_dir=${HOME:-/root}
  out=$(ui_input 'Package RootFS' 'Output tarball path' "$default_dir/$base-$stamp.$ext") || return 0
  case $out in /*) :;; *) ui_msg Package 'Output path must be absolute.'; return 1;; esac
  [ "$out" != "$src" ] || { ui_msg Package 'Output cannot be the RootFS directory.'; return 1; }
  case $out in "$src"/*) ui_msg Package 'Output tarball cannot be created inside the RootFS being archived.'; return 1;; esac
  parent=$(dirname "$out")
  as_root mkdir -p "$parent" || { ui_msg Package "Cannot create output directory:\n$parent"; return 1; }
  [ ! -e "$out" ] || ui_yesno Package "Overwrite existing file?\n$out" || return 0

  ui_yesno Package "Create archive?\n\nSource: $src\nOutput: $out\n\nRuntime mount contents under dev, proc, sys and run will be excluded." || return 0

  excludes="--exclude=./dev/* --exclude=./proc/* --exclude=./sys/* --exclude=./run/* --exclude=./tmp/ish-aok-*"
  case $format in
    zstd) (cd "$src" && tar $excludes -cf - .) | zstd -T0 -q -o "$out";;
    gzip) (cd "$src" && tar $excludes -cf - .) | gzip -c >"$out";;
    xz) (cd "$src" && tar $excludes -cf - .) | xz -c >"$out";;
    tar) (cd "$src" && tar $excludes -cf "$out" .);;
  esac
  rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$out" 2>/dev/null || true
    ui_msg Package 'Archive creation failed.'
    return "$rc"
  fi
  if have sha256sum; then
    (cd "$parent" && sha256sum "$(basename "$out")" >"$(basename "$out").sha256")
  elif have shasum; then
    (cd "$parent" && shasum -a 256 "$(basename "$out")" >"$(basename "$out").sha256")
  fi
  ui_msg Package "RootFS archive created:\n$out"
}

V951_MOUNTED=
v951_mount_one(){
  target=$1; shift
  mkdir -p "$target" || return 1
  aok_mountpoint "$target" && return 0
  as_root "$@" || return 1
  V951_MOUNTED="$target $V951_MOUNTED"
}

v951_chroot_cleanup(){
  for m in $V951_MOUNTED; do
    aok_mountpoint "$m" && as_root umount -l "$m" 2>/dev/null || true
  done
  V951_MOUNTED=
}

v951_chroot_any_directory(){
  root=$(v951_choose_rootfs_directory 'Chroot any RootFS directory') || {
    rc=$?; [ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$rc";
  }
  [ "$root" != / ] || { ui_msg Chroot 'The host root directory cannot be opened as an external chroot.'; return 1; }
  rootfs_anywhere_looks_valid "$root" || ui_yesno Chroot "The selected directory may not be a complete RootFS:\n\n$root\n\nContinue?" || return 0
  have chroot || { ui_msg Chroot 'The chroot command is not installed.'; return 1; }
  need_root || return 1

  shell=/bin/sh
  [ -x "$root/bin/bash" ] && shell=/bin/bash
  shell=$(ui_input Chroot 'Shell or command inside the RootFS' "$shell") || return 0
  [ -x "$root$shell" ] || { ui_msg Chroot "Command is not executable inside RootFS:\n$shell"; return 1; }

  profile=$(ui_menu 'Chroot mount profile' 'Choose virtual filesystems to prepare.' standard 'dev, devpts, proc, sys and run' minimal 'dev, devpts and proc' none 'Do not mount virtual filesystems') || {
    rc=$?; [ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$rc";
  }

  V951_MOUNTED=
  mkdir -p "$root/dev" "$root/dev/pts" "$root/proc" "$root/sys" "$root/run" || return 1
  case $profile in
    standard|minimal)
      if ! aok_mountpoint "$root/dev"; then
        as_root mount --rbind /dev "$root/dev" 2>/dev/null || as_root mount -o bind /dev "$root/dev" || { v951_chroot_cleanup; return 1; }
        V951_MOUNTED="$root/dev $V951_MOUNTED"
      fi
      v951_mount_one "$root/proc" mount -t proc proc "$root/proc" || true
      aok_mountpoint "$root/dev/pts" || v951_mount_one "$root/dev/pts" mount -t devpts devpts "$root/dev/pts" || true
      ;;
  esac
  if [ "$profile" = standard ]; then
    [ -d /sys ] && v951_mount_one "$root/sys" mount --rbind /sys "$root/sys" 2>/dev/null || true
    [ -d /run ] && v951_mount_one "$root/run" mount -o bind /run "$root/run" 2>/dev/null || true
  fi

  if [ -r /etc/resolv.conf ]; then
    [ -e "$root/etc/resolv.conf" ] && cp "$root/etc/resolv.conf" "$TMP_DIR/resolv.conf.v951" 2>/dev/null || true
    as_root cp /etc/resolv.conf "$root/etc/resolv.conf" 2>/dev/null || true
  fi

  rootfs_register "$root" >/dev/null 2>&1 || true
  rootfs_anywhere_remember "$root" >/dev/null 2>&1 || true
  as_root chroot "$root" "$shell"
  rc=$?

  [ -f "$TMP_DIR/resolv.conf.v951" ] && as_root cp "$TMP_DIR/resolv.conf.v951" "$root/etc/resolv.conf" 2>/dev/null || true
  rm -f "$TMP_DIR/resolv.conf.v951" 2>/dev/null || true
  v951_chroot_cleanup
  return "$rc"
}

v951_rootfs_tools_report(){
  printf '%s %s — Portable RootFS Tools\n\n' "$PROGRAM" "$VERSION"
  printf 'Package arbitrary RootFS directory: available\n'
  printf 'Chroot arbitrary RootFS directory: available\n'
  printf 'Back status: %s\n' "${UI_MENU_BACK_RC:-90}"
}
