#!/bin/sh
ROOTFS_REGISTRY_DIR=$AOK_STATE_DIR/rootfs-registry
ROOTFS_REPORT_DIR=$REPORT_DIR/rootfs
mkdir -p "$ROOTFS_REGISTRY_DIR" "$ROOTFS_REPORT_DIR" 2>/dev/null || true

rootfs_id(){ aok_safe_name "$(printf '%s' "$1" | sed 's#^/##; s#/#-#g')"; }
rootfs_meta_file(){ printf '%s/%s.meta' "$ROOTFS_REGISTRY_DIR" "$(rootfs_id "$1")"; }
rootfs_meta_get(){ f=$(rootfs_meta_file "$1"); k=$2; [ -r "$f" ] && sed -n "s/^$k=//p" "$f" | head -1; }
rootfs_register(){
  r=$1; [ -d "$r" ] || return 1; f=$(rootfs_meta_file "$r");
  label=$(rootfs_meta_get "$r" label); [ -n "$label" ] || label=$(basename "$r"); [ "$r" = / ] && label=host
  os=$(aok_root_os "$r"); arch=$(aok_root_arch "$r")
  { printf 'path=%s\n' "$r"; printf 'label=%s\n' "$label"; printf 'os=%s\n' "$os"; printf 'arch=%s\n' "$arch"; printf 'tags=%s\n' "$(rootfs_meta_get "$r" tags)"; printf 'description=%s\n' "$(rootfs_meta_get "$r" description)"; printf 'updated=%s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"; } >"$f"
}
rootfs_register_all(){ aok_find_roots | while IFS= read -r r; do [ -n "$r" ] && rootfs_register "$r"; done; }
rootfs_list(){ rootfs_register_all; for f in "$ROOTFS_REGISTRY_DIR"/*.meta; do [ -r "$f" ] || continue; sed -n 's/^path=//p' "$f" | head -1; done | awk 'NF&&!seen[$0]++'; }
rootfs_set_meta(){ r=$1; key=$2; val=$3; rootfs_register "$r" || return; f=$(rootfs_meta_file "$r"); t=$TMP_DIR/meta; awk -F= -v k="$key" '$1!=k{print}' "$f" >"$t"; printf '%s=%s\n' "$key" "$val" >>"$t"; mv "$t" "$f"; }
rootfs_select_registered(){
  set --; rootfs_list | while IFS= read -r r; do :; done
  roots=$(rootfs_list); [ -n "$roots" ] || { ui_msg RootFS 'No root filesystems discovered.'; return 1; }
  oldifs=$IFS; IFS='
'; for r in $roots; do [ -n "$r" ] || continue; label=$(rootfs_meta_get "$r" label); os=$(rootfs_meta_get "$r" os); set -- "$@" "$r" "$label — $os"; done; IFS=$oldifs
  ui_menu 'Select RootFS' 'Choose a registered or discovered root filesystem.' "$@"
}
rootfs_size_bytes(){ du -sk "$1" 2>/dev/null | awk '{print $1*1024}'; }
rootfs_human_size(){ du -sh "$1" 2>/dev/null | awk '{print $1}'; }
rootfs_manifest(){
  r=$1; out=$2; { echo "path=$r"; echo "label=$(rootfs_meta_get "$r" label)"; echo "os=$(aok_root_os "$r")"; echo "arch=$(aok_root_arch "$r")"; echo "size=$(rootfs_human_size "$r")"; echo "generated=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"; echo; echo '[packages]';
    if [ -x "$r/usr/bin/dpkg-query" ]; then chroot "$r" dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null || true;
    elif [ -r "$r/lib/apk/db/installed" ]; then awk '/^P:/{p=substr($0,3)}/^V:/{print p"\t"substr($0,3)}' "$r/lib/apk/db/installed";
    elif [ -r "$r/var/lib/pacman/local" ]; then find "$r/var/lib/pacman/local" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null;
    fi
    echo; echo '[services]'; find "$r/etc/init.d" "$r/etc/rc.d" -maxdepth 1 -type f 2>/dev/null | sed "s#^$r##" | sort;
  } >"$out"
}

rootfs_detect_init(){ r=$1; if [ -d "$r/etc/runlevels" ]; then echo openrc; elif [ -d "$r/etc/init.d" ]; then echo sysvinit; elif [ -d "$r/etc/systemd" ]; then echo systemd; else echo unknown; fi; }
rootfs_detect_pkgmgr(){ r=$1; for p in apt-get apk pacman xbps-install dnf emerge; do case $p in apt-get) f=$r/usr/bin/apt-get;; apk) f=$r/sbin/apk;; pacman) f=$r/usr/bin/pacman;; xbps-install) f=$r/usr/bin/xbps-install;; dnf) f=$r/usr/bin/dnf;; emerge) f=$r/usr/bin/emerge;; esac; [ -x "$f" ] && { echo "$p"; return; }; done; echo unknown; }
rootfs_detect_shell(){ r=$1; awk -F: '$1=="root"{print $7; exit}' "$r/etc/passwd" 2>/dev/null || true; }
rootfs_detect_editor(){ r=$1; for e in nvim vim nano micro helix emacs; do [ -x "$r/usr/bin/$e" -o -x "$r/bin/$e" ] && { echo "$e"; return; }; done; echo unknown; }
rootfs_registry_refresh(){
  r=$1; rootfs_register "$r" || return 1
  rootfs_set_meta "$r" init "$(rootfs_detect_init "$r")"
  rootfs_set_meta "$r" package_manager "$(rootfs_detect_pkgmgr "$r")"
  rootfs_set_meta "$r" shell "$(rootfs_detect_shell "$r")"
  rootfs_set_meta "$r" editor "$(rootfs_detect_editor "$r")"
  rootfs_set_meta "$r" last_used "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"
  [ -n "$(rootfs_meta_get "$r" created)" ] || rootfs_set_meta "$r" created "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"
  [ -n "$(rootfs_meta_get "$r" favorite)" ] || rootfs_set_meta "$r" favorite no
}
rootfs_registry_search(){
  q=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  rootfs_list | while IFS= read -r r; do
    [ -n "$r" ] || continue
    f=$(rootfs_meta_file "$r")
    blob=$(cat "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]')
    printf '%s\n%s\n' "$r" "$blob" | grep -F "$q" >/dev/null 2>&1 && printf '%s\n' "$r"
  done
}
rootfs_registry_table(){
  rootfs_list | while IFS= read -r r; do
    rootfs_registry_refresh "$r"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$r" "$(rootfs_meta_get "$r" label)" "$(rootfs_meta_get "$r" os)" \
      "$(rootfs_meta_get "$r" arch)" "$(rootfs_meta_get "$r" init)" "$(rootfs_meta_get "$r" package_manager)"
  done
}
