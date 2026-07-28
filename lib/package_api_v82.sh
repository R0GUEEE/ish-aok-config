#!/bin/sh
# Unified package adapter API (v8.2)
pkg_api_manager(){
  if [ -n "${PKG_MGR:-}" ]; then printf '%s\n' "$PKG_MGR"; return; fi
  for p in apt-get apk pacman dnf xbps-install emerge zypper; do
    command -v "$p" >/dev/null 2>&1 || continue
    case $p in apt-get) echo apt;; xbps-install) echo xbps;; *) echo "$p";; esac
    return
  done
  return 1
}
pkg_api_exec(){ op=$1; shift; old=${PKG_MGR:-}; PKG_MGR=$(pkg_api_manager) || return 127; export PKG_MGR; "$op" "$@"; rc=$?; PKG_MGR=$old; export PKG_MGR; return $rc; }
pkg_refresh(){ pkg_api_exec pkg_update; }
pkg_install_packages(){ pkg_api_exec pkg_install "$@"; }
pkg_remove_packages(){ pkg_api_exec pkg_remove "$@"; }
pkg_upgrade_packages(){ pkg_api_exec pkg_upgrade; }
pkg_search(){
  q=$1; m=$(pkg_api_manager) || return 127
  case $m in apt) apt-cache search -- "$q";; apk) apk search -v "$q";; pacman) pacman -Ss -- "$q";; dnf|yum) "$m" search "$q";; xbps) xbps-query -Rs "$q";; emerge) emerge --search "$q";; zypper) zypper search "$q";; *) return 1;; esac
}
pkg_info(){ p=$1; m=$(pkg_api_manager) || return 127; case $m in apt) apt-cache show -- "$p";; apk) apk info -a "$p";; pacman) pacman -Si -- "$p";; dnf|yum) "$m" info "$p";; xbps) xbps-query -RS "$p";; emerge) emerge --info "$p";; zypper) zypper info "$p";; esac; }
pkg_list_installed(){ m=$(pkg_api_manager) || return 127; case $m in apt) dpkg-query -W -f='${binary:Package}\t${Version}\n';; apk) apk info -v;; pacman) pacman -Q;; dnf|yum) rpm -qa;; xbps) xbps-query -l;; emerge) qlist -Iv 2>/dev/null || find /var/db/pkg -mindepth 2 -maxdepth 2 -type d 2>/dev/null;; zypper) rpm -qa;; esac; }
pkg_list_orphans(){ m=$(pkg_api_manager) || return 127; case $m in apt) deborphan 2>/dev/null || apt-mark showauto;; apk) apk info -r 2>/dev/null;; pacman) pacman -Qtdq;; dnf|yum) "$m" repoquery --unneeded 2>/dev/null;; xbps) xbps-query -O;; emerge) emerge --depclean --pretend;; zypper) zypper packages --orphaned;; esac; }
# Compatibility aliases
pkg_adapter_refresh(){ pkg_refresh "$@"; }
pkg_adapter_install(){ pkg_install_packages "$@"; }
pkg_adapter_remove(){ pkg_remove_packages "$@"; }
pkg_adapter_upgrade(){ pkg_upgrade_packages "$@"; }
