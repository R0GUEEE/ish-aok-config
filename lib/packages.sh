#!/bin/sh
_pkg_exec(){
    title=$1; shift
    if [ "${PROGRESS_CONTEXT:-no}" = yes ] || [ "${PROGRESS_ENABLED:-yes}" != yes ]; then
        run_root "$@"
    else
        progress_run "$title" run_root "$@"
        rc=$?
        progress_summary "$title" "$rc" "$PROGRESS_LAST_LOG"
        return "$rc"
    fi
}
pkg_update(){ case $PKG_MGR in apt) _pkg_exec 'Updating APT package indexes' apt-get update;; apk) _pkg_exec 'Updating APK package indexes' apk update;; pacman) _pkg_exec 'Synchronizing Pacman databases' pacman -Sy;; dnf) _pkg_exec 'Refreshing DNF metadata' dnf makecache;; yum) _pkg_exec 'Refreshing YUM metadata' yum makecache;; xbps) _pkg_exec 'Synchronizing XBPS repositories' xbps-install -S;; emerge) _pkg_exec 'Synchronizing Portage tree' emerge --sync;; zypper) _pkg_exec 'Refreshing Zypper repositories' zypper refresh;; *) return 1;; esac; }
pkg_upgrade(){ case $PKG_MGR in apt) _pkg_exec 'Upgrading APT packages' apt-get upgrade -y;; apk) _pkg_exec 'Upgrading APK packages' apk upgrade;; pacman) _pkg_exec 'Upgrading Pacman packages' pacman -Syu --noconfirm;; dnf) _pkg_exec 'Upgrading DNF packages' dnf upgrade -y;; yum) _pkg_exec 'Upgrading YUM packages' yum update -y;; xbps) _pkg_exec 'Upgrading XBPS packages' xbps-install -Suy;; emerge) _pkg_exec 'Upgrading Portage world set' emerge -avuDN @world;; zypper) _pkg_exec 'Upgrading Zypper packages' zypper --non-interactive update;; *) return 1;; esac; }
pkg_install(){
    [ "$#" -gt 0 ] || return 0
    case $PKG_MGR in
        apt) _pkg_exec "Installing packages: $*" apt-get install -y "$@";;
        apk) _pkg_exec "Installing packages: $*" apk add "$@";;
        pacman) _pkg_exec "Installing packages: $*" pacman -S --needed --noconfirm "$@";;
        dnf) _pkg_exec "Installing packages: $*" dnf install -y "$@";;
        yum) _pkg_exec "Installing packages: $*" yum install -y "$@";;
        xbps) _pkg_exec "Installing packages: $*" xbps-install -y "$@";;
        emerge) _pkg_exec "Installing packages: $*" emerge "$@";;
        zypper) _pkg_exec "Installing packages: $*" zypper --non-interactive install "$@";;
        *) return 1;;
    esac
}
pkg_remove(){
    [ "$#" -gt 0 ] || return 0
    case $PKG_MGR in
        apt) _pkg_exec "Removing packages: $*" apt-get remove -y "$@";;
        apk) _pkg_exec "Removing packages: $*" apk del "$@";;
        pacman) _pkg_exec "Removing packages: $*" pacman -Rns --noconfirm "$@";;
        dnf) _pkg_exec "Removing packages: $*" dnf remove -y "$@";;
        yum) _pkg_exec "Removing packages: $*" yum remove -y "$@";;
        xbps) _pkg_exec "Removing packages: $*" xbps-remove -y "$@";;
        emerge) _pkg_exec "Removing packages: $*" emerge -C "$@";;
        zypper) _pkg_exec "Removing packages: $*" zypper --non-interactive remove "$@";;
        *) return 1;;
    esac
}
