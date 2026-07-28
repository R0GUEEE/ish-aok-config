#!/bin/sh

V85_STATE_DIR=${V85_STATE_DIR:-$STATE_DIR/service-v85}
V85_REPORT_DIR=${V85_REPORT_DIR:-$REPORT_DIR/service-v85}
mkdir -p "$V85_STATE_DIR" "$V85_REPORT_DIR" 2>/dev/null || true

service_v85_root(){ r=${1:-$(active_rootfs 2>/dev/null || echo /)}; [ -d "$r" ] && printf '%s\n' "$r"; }
service_v85_init(){ r=$(service_v85_root "${1:-}") || return 1; v84_detect_init "$r" 2>/dev/null || rootfs_detect_init "$r" 2>/dev/null || echo unknown; }
service_v85_path(){ r=$1; p=$2; [ "$r" = / ] && printf '%s\n' "$p" || printf '%s%s\n' "$r" "$p"; }
service_v85_safe_name(){ printf '%s' "$1" | sed 's#[^A-Za-z0-9_.@+-]#_#g'; }
service_v85_validate_name(){ case ${1:-} in ''|*[!A-Za-z0-9_.@+-]*) return 1;; *) return 0;; esac; }

service_v85_exec(){
  r=$1; shift
  [ "$r" = / ] && { as_root "$@"; return; }
  have chroot || return 127
  as_root chroot "$r" "$@"
}

service_v85_list(){
  r=$(service_v85_root "${1:-}") || return 1
  init=$(service_v85_init "$r")
  case $init in
    openrc)
      d=$(service_v85_path "$r" /etc/init.d); [ -d "$d" ] && find "$d" -mindepth 1 -maxdepth 1 -type f -o -type l 2>/dev/null | sed 's#.*/##' | sort -u;;
    runit)
      d=$(service_v85_path "$r" /etc/sv); [ -d "$d" ] && find "$d" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's#.*/##' | sort -u;;
    systemd)
      for d in /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system; do q=$(service_v85_path "$r" "$d"); [ -d "$q" ] && find "$q" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -name '*.service' 2>/dev/null | sed 's#.*/##;s/\.service$//' ; done | sort -u;;
    sysv|sysvinit)
      d=$(service_v85_path "$r" /etc/init.d); [ -d "$d" ] && find "$d" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | sed 's#.*/##' | grep -v '^README$' | sort -u;;
    *) return 1;;
  esac
}

service_v85_enabled(){
  r=$(service_v85_root "${1:-}") || return 1; s=$2; service_v85_validate_name "$s" || return 2
  init=$(service_v85_init "$r")
  case $init in
    openrc) find "$(service_v85_path "$r" /etc/runlevels)" -type l -name "$s" 2>/dev/null | grep -q .;;
    runit) [ -e "$(service_v85_path "$r" "/var/service/$s")" ] || [ -e "$(service_v85_path "$r" "/etc/service/$s")" ];;
    systemd) find "$(service_v85_path "$r" /etc/systemd/system)" -type l -name "$s.service" 2>/dev/null | grep -q .;;
    sysv|sysvinit) find "$(service_v85_path "$r" /etc)" -maxdepth 2 -type l -name "S??$s" 2>/dev/null | grep -q .;;
    *) return 1;;
  esac
}

service_v85_status(){
  r=$(service_v85_root "${1:-}") || return 1; s=$2; service_v85_validate_name "$s" || return 2
  init=$(service_v85_init "$r")
  case $init in
    openrc) service_v85_exec "$r" rc-service "$s" status;;
    runit) service_v85_exec "$r" sv status "$s";;
    systemd) [ "$r" = / ] && have systemctl && systemctl is-active "$s" || printf '%s\n' 'offline-rootfs';;
    sysv|sysvinit) service_v85_exec "$r" service "$s" status;;
    *) return 1;;
  esac
}

service_v85_control(){
  r=$(service_v85_root "${1:-}") || return 1; s=$2; action=$3
  service_v85_validate_name "$s" || return 2
  case $action in start|stop|restart|reload|status) :;; *) return 2;; esac
  init=$(service_v85_init "$r")
  case $init in
    openrc) service_v85_exec "$r" rc-service "$s" "$action";;
    runit) case $action in start) a=up;; stop) a=down;; restart|reload) a=restart;; status) a=status;; esac; service_v85_exec "$r" sv "$a" "$s";;
    systemd) [ "$r" = / ] || { printf '%s\n' 'systemd service execution is unavailable for an offline RootFS.' >&2; return 1; }; as_root systemctl "$action" "$s";;
    sysv|sysvinit) service_v85_exec "$r" service "$s" "$action";;
    *) return 1;;
  esac
}

service_v85_enable(){
  r=$(service_v85_root "${1:-}") || return 1; s=$2; runlevel=${3:-default}; service_v85_validate_name "$s" || return 2
  init=$(service_v85_init "$r")
  case $init in
    openrc) service_v85_exec "$r" rc-update add "$s" "$runlevel";;
    runit)
      src=$(service_v85_path "$r" "/etc/sv/$s"); dst=$(service_v85_path "$r" "/var/service/$s"); [ -d "$src" ] || return 1; mkdir -p "$(dirname "$dst")"; [ -e "$dst" ] || ln -s "/etc/sv/$s" "$dst";;
    systemd) [ "$r" = / ] && as_root systemctl enable "$s" || { printf '%s\n' 'Use preset/unit-link auditing for an offline systemd RootFS.' >&2; return 1; };;
    sysv|sysvinit)
      if [ "$r" = / ]; then if have update-rc.d; then as_root update-rc.d "$s" defaults; elif have chkconfig; then as_root chkconfig "$s" on; else return 127; fi
      else service_v85_exec "$r" sh -c 'command -v update-rc.d >/dev/null 2>&1 && exec update-rc.d "$1" defaults; command -v chkconfig >/dev/null 2>&1 && exec chkconfig "$1" on; exit 127' sh "$s"; fi;;
    *) return 1;;
  esac
}

service_v85_disable(){
  r=$(service_v85_root "${1:-}") || return 1; s=$2; runlevel=${3:-default}; service_v85_validate_name "$s" || return 2
  init=$(service_v85_init "$r")
  case $init in
    openrc) service_v85_exec "$r" rc-update del "$s" "$runlevel";;
    runit) rm -f "$(service_v85_path "$r" "/var/service/$s")" "$(service_v85_path "$r" "/etc/service/$s")";;
    systemd) [ "$r" = / ] && as_root systemctl disable "$s" || return 1;;
    sysv|sysvinit)
      if [ "$r" = / ]; then if have update-rc.d; then as_root update-rc.d -f "$s" remove; elif have chkconfig; then as_root chkconfig "$s" off; else return 127; fi
      else service_v85_exec "$r" sh -c 'command -v update-rc.d >/dev/null 2>&1 && exec update-rc.d -f "$1" remove; command -v chkconfig >/dev/null 2>&1 && exec chkconfig "$1" off; exit 127' sh "$s"; fi;;
    *) return 1;;
  esac
}

service_v85_boot_audit_to(){
  r=$(service_v85_root "${1:-}") || return 1; out=$2; init=$(service_v85_init "$r")
  {
    printf 'RootFS: %s\nInit system: %s\n\n' "$r" "$init"
    printf '[enabled services]\n'
    service_v85_list "$r" 2>/dev/null | while IFS= read -r s; do service_v85_enabled "$r" "$s" && printf '%s\n' "$s"; done
    printf '\n[boot-layout warnings]\n'
    case $init in
      openrc) [ -d "$(service_v85_path "$r" /etc/runlevels/default)" ] || echo 'Missing OpenRC default runlevel directory.';;
      runit) [ -d "$(service_v85_path "$r" /etc/sv)" ] || echo 'Missing /etc/sv.'; [ -d "$(service_v85_path "$r" /var/service)" ] || echo 'Missing /var/service.';;
      sysv|sysvinit) [ -d "$(service_v85_path "$r" /etc/init.d)" ] || echo 'Missing /etc/init.d.'; find "$(service_v85_path "$r" /etc)" -maxdepth 2 -type l -name 'S??*' 2>/dev/null | grep -q . || echo 'No SysV start links were found.';;
      systemd) echo 'systemd is not a native iSH-AOK service target; unit files are audited only.';;
      *) echo 'No supported service manager was detected.';;
    esac
    printf '\n[missing service targets]\n'
    case $init in
      openrc) find "$(service_v85_path "$r" /etc/runlevels)" -type l 2>/dev/null | while IFS= read -r l; do t=$(readlink "$l" 2>/dev/null || true); case $t in /*) q=$(service_v85_path "$r" "$t");; *) q=$(dirname "$l")/$t;; esac; [ -e "$q" ] || printf '%s -> %s\n' "$l" "$t"; done;;
      runit) find "$(service_v85_path "$r" /var/service)" -type l 2>/dev/null | while IFS= read -r l; do [ -e "$l" ] || echo "$l"; done;;
      sysv|sysvinit) find "$(service_v85_path "$r" /etc)" -maxdepth 2 -type l -name '[SK][0-9][0-9]*' 2>/dev/null | while IFS= read -r l; do [ -e "$l" ] || echo "$l"; done;;
    esac
  } >"$out"
}

service_v85_report(){
  r=$(service_v85_root "${1:-}") || return 1; stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now); out=$V85_REPORT_DIR/service-$stamp.txt
  service_v85_boot_audit_to "$r" "$out" || return 1; printf '%s\n' "$out"
}
