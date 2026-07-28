#!/bin/sh
init_detect_details(){
    {
        printf 'Detected init: %s\n' "$INIT_SYSTEM"
        printf 'PID 1: '; ps -p 1 -o comm= 2>/dev/null || true
        printf '/sbin/init: '; ls -l /sbin/init 2>/dev/null || true
        printf '\nInstalled packages:\n'
        case $PKG_MGR in
            apt) dpkg-query -W 'sysvinit*' 'systemd*' 'openrc*' 2>/dev/null || true;;
            apk) apk info -vv 2>/dev/null | grep -E '^(openrc|sysvinit|systemd)' || true;;
            pacman) pacman -Q 2>/dev/null | grep -E '^(systemd|openrc|sysvinit)' || true;;
            dnf|yum) rpm -qa 2>/dev/null | grep -E '^(systemd|sysvinit|initscripts)' || true;;
        esac
        printf '\nService layout:\n'
        find /etc -maxdepth 3 -type d \( -name 'rc?.d' -o -name runlevels -o -name systemd \) 2>/dev/null | sort
    } >"$REPORT_DIR/init-system.txt"
    ui_text 'Init system report' "$(cat "$REPORT_DIR/init-system.txt")"
}
init_snapshot(){
    d="$BACKUP_DIR/init-$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now)"; mkdir -p "$d"
    for f in /etc/inittab /etc/default/grub /etc/init.d /etc/rc0.d /etc/rc1.d /etc/rc2.d /etc/rc3.d /etc/rc4.d /etc/rc5.d /etc/rc6.d /sbin/init; do [ -e "$f" ] && cp -a "$f" "$d/" 2>/dev/null || true; done
    case $PKG_MGR in apt) dpkg-query -W >"$d/packages.txt" 2>/dev/null;; apk) apk info -vv >"$d/packages.txt" 2>/dev/null;; pacman) pacman -Q >"$d/packages.txt" 2>/dev/null;; esac
    printf '%s\n' "$d"
}
install_sysvinit_packages(){
    need_root || return
    case $PKG_MGR in
        apt) run_capture 'Install SysVinit' run_root apt-get install -y sysvinit-core sysvinit-utils initscripts orphan-sysvinit-scripts;;
        apk) ui_msg SysVinit 'Alpine is OpenRC-native. Installing classic Debian SysVinit is not supported; use OpenRC configuration instead.';;
        pacman) ui_msg SysVinit 'Arch Linux does not provide a supported SysVinit migration in official repositories. A manual AUR-based conversion is intentionally not automated.';;
        dnf|yum) run_capture 'Install SysV compatibility' run_root "$PKG_MGR" install -y initscripts chkconfig;;
        *) ui_msg SysVinit "No automatic package adapter for $PKG_MGR.";;
    esac
}
generate_inittab_host(){
    body='id:3:initdefault:\nsi::sysinit:/etc/init.d/rcS\nl0:0:wait:/etc/init.d/rc 0\nl1:1:wait:/etc/init.d/rc 1\nl2:2:wait:/etc/init.d/rc 2\nl3:3:wait:/etc/init.d/rc 3\nl4:4:wait:/etc/init.d/rc 4\nl5:5:wait:/etc/init.d/rc 5\nl6:6:wait:/etc/init.d/rc 6\nz6:6:respawn:/sbin/sulogin\nca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now\n1:2345:respawn:/sbin/getty 38400 tty1'
    write_file /etc/inittab 644 "$body"
}
sysv_service_links(){
    s=$(ui_input Service 'Init script name in /etc/init.d:' ssh) || return
    if have update-rc.d; then run_capture 'Enable SysV service' run_root update-rc.d "$s" defaults
    elif have chkconfig; then run_capture 'Enable SysV service' run_root chkconfig "$s" on
    else ui_msg SysVinit 'No update-rc.d or chkconfig command was found.'; fi
}
systemd_dependency_audit(){ grep -RIlE 'systemctl|systemd-run|journalctl|/run/systemd|libsystemd' /etc /usr/local /opt 2>/dev/null | head -n 500 >"$REPORT_DIR/systemd-dependencies.txt"; ui_text 'systemd dependency audit' "$(cat "$REPORT_DIR/systemd-dependencies.txt")"; }
sysv_migrate_host(){
    [ "$PKG_MGR" = apt ] || { ui_msg Migration 'Automated replacement is currently limited to APT-based Debian/Devuan/Ubuntu roots.'; return; }
    ui_yesno 'Replace systemd' 'This changes PID 1 packages and may make a normal Debian/Ubuntu installation unbootable. iSH-AOK root filesystems generally do not boot a kernel normally. Create a snapshot and continue?' || return
    snap=$(init_snapshot); verbose "Init snapshot: $snap"
    run_capture 'Install SysVinit' run_root apt-get install -y sysvinit-core sysvinit-utils initscripts orphan-sysvinit-scripts || return
    generate_inittab_host
    run_capture 'Switch init package' run_root apt-get remove -y systemd-sysv || { ui_msg Migration "Package removal failed. Snapshot: $snap"; return; }
    if dpkg-query -W systemd >/dev/null 2>&1; then
        ui_yesno Migration 'Remove remaining systemd package where dependencies permit?' && run_capture 'Remove systemd' run_root apt-get remove -y systemd || true
    fi
    detect_system
    ui_msg Migration "Migration actions completed. Review /etc/inittab and enabled services before restarting. Backup: $snap"
}
sysv_rollback_info(){ ui_text Rollback "Init snapshots are stored under:\n$BACKUP_DIR/init-*\n\nPackage rollback must use the package manager and the packages.txt file in the selected snapshot. Configuration files can be copied back manually from that directory."; }
init_system_menu(){ while :; do c=$(ui_menu 'Init system & SysVinit' "Detected: $INIT_SYSTEM | package manager: $PKG_MGR" detect 'Detailed init-system report' install 'Install SysVinit or compatibility packages' migrate 'Replace systemd with SysVinit (APT)' inittab 'Generate /etc/inittab' services 'Enable a SysV service at boot' scripts 'Browse /etc/init.d scripts' audit 'Audit systemd dependencies' snapshot 'Create init configuration snapshot' rollback 'Show rollback information' openrc 'Open OpenRC/service manager') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in detect) init_detect_details;; install) install_sysvinit_packages;; migrate) sysv_migrate_host;; inittab) generate_inittab_host;; services) sysv_service_links;; scripts) ui_text 'Init scripts' "$(ls -la /etc/init.d 2>/dev/null)";; audit) systemd_dependency_audit;; snapshot) d=$(init_snapshot); ui_msg Snapshot "$d";; rollback) sysv_rollback_info;; openrc) services_menu;; esac; done; }
