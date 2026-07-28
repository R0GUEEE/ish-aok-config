#!/bin/sh
detect_system(){
 [ -r /etc/os-release ] && { DISTRO_ID=$(sed -n 's/^ID=//p' /etc/os-release|head -1|tr -d '"'); DISTRO_LIKE=$(sed -n 's/^ID_LIKE=//p' /etc/os-release|head -1|tr -d '"'); }
 for p in apk apt-get pacman dnf yum xbps-install emerge zypper; do have "$p" && { case $p in apt-get) PKG_MGR=apt;; xbps-install) PKG_MGR=xbps;; *) PKG_MGR=$p;; esac; break; }; done
 if have rc-service; then INIT_SYSTEM=openrc; elif have systemctl && [ -d /run/systemd/system ]; then INIT_SYSTEM=systemd; elif have sv; then INIT_SYSTEM=runit; elif [ -x /etc/init.d/cron ] || [ -x /etc/init.d/sshd ]; then INIT_SYSTEM=sysv; else INIT_SYSTEM=unknown; fi
 [ -d /opt/AOK ] || grep -q aokfs /proc/mounts 2>/dev/null && AOK_DETECTED=yes
}
package_installed(){ case $PKG_MGR in apt) dpkg-query -W -f='${Status}' "$1" 2>/dev/null|grep -q 'install ok installed';; apk) apk info -e "$1" >/dev/null 2>&1;; pacman) pacman -Q "$1" >/dev/null 2>&1;; dnf|yum) rpm -q "$1" >/dev/null 2>&1;; xbps) xbps-query "$1" >/dev/null 2>&1;; *) have "$1";; esac; }
service_state(){ s=$1; case $INIT_SYSTEM in openrc) rc-service "$s" status >/dev/null 2>&1 && echo running || { rc-update show 2>/dev/null|grep -q "[[:space:]]$s[[:space:]]" && echo enabled || echo stopped; };; systemd) systemctl is-active "$s" 2>/dev/null || systemctl is-enabled "$s" 2>/dev/null || echo missing;; runit) sv status "$s" 2>/dev/null || echo missing;; sysv) service "$s" status >/dev/null 2>&1 && echo running || [ -x "/etc/init.d/$s" ] && echo installed || echo missing;; *) echo unknown;; esac; }
scan_system(){
 out=$REPORT_DIR/inventory.txt
 { echo "Generated: $(date)"; echo "Distribution: $DISTRO_ID ($DISTRO_LIKE)"; echo "Architecture: $ARCH"; echo "Package manager: $PKG_MGR"; echo "Init: $INIT_SYSTEM"; echo "iSH-AOK: $AOK_DETECTED"; echo; echo '[Shells]'; for x in sh ash bash zsh fish dash mksh ksh nu; do have "$x" && command -v "$x"; done; echo; echo '[Editors]'; for x in nano vi vim nvim micro hx helix emacs joe mg; do have "$x" && printf '%s: %s\n' "$x" "$(command -v "$x")"; done; echo; echo '[Services]'; for x in ssh sshd cron crond rsyslog syslog-ng chronyd ntpd; do printf '%s: %s\n' "$x" "$(service_state "$x")"; done; echo; echo '[Config files]'; for f in "$CURRENT_HOME/.profile" "$CURRENT_HOME/.bashrc" "$CURRENT_HOME/.zshrc" "$CURRENT_HOME/.nanorc" "$CURRENT_HOME/.vimrc" /etc/ssh/sshd_config /etc/hosts /etc/resolv.conf; do [ -e "$f" ] && echo "present $f" || echo "missing $f"; done; echo; echo '[Memory]'; cat /proc/meminfo 2>/dev/null|head -12; echo; echo '[Filesystems]'; df -h 2>/dev/null; } >"$out"
}
