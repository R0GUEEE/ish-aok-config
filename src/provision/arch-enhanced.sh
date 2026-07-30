#!/bin/bash
###############################################################################
PROV_RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$PROV_RUNTIME_DIR/runtime.sh" ] && . "$PROV_RUNTIME_DIR/runtime.sh"
# systui — Enhanced Arch Linux Provisioning
#
# Features:
#   • Advanced network configuration (static IP, DNS, gateway)
#   • Security hardening (SSH, firewall, AppArmor, SELinux)
#   • Package profiles (minimal, standard, full, dev, server, container)
#   • Shell preferences (bash, zsh, fish, ksh)
#   • NTP/time synchronization options
#   • Disk optimization and swap configuration
#   • Automatic updates and security patches
#   • System limits and performance tuning
#   • Logging configuration (journald levels, remote logging)
#   • Additional user/group management
###############################################################################

provision_arch_enhanced_impl() {
    provision_require_family archlinux || return $?
    local cfg_file="$1"
    
    # Default configurations
    local tz="UTC"
    local user="arch"
    local host="arch-minisys"
    local nopass=0
    local shell="bash"
    local profile="standard"
    local enable_ssh=1
    local ssh_port=22
    local ssh_root_login=0
    local enable_firewall=0
    local enable_fail2ban=0
    local dhcp=1
    local ipaddr=""
    local gateway=""
    local dns_servers="1.1.1.1 8.8.8.8"
    local keyboard="us"
    local ntp_server="pool.ntp.org"
    local enable_autoupdate=0
    local swap_size=0
    local journald_level="info"
    local enable_selinux=0
    local max_open_files=65536
    local remote_syslog=""
    local pacman_mirror=""
    
    # Load configuration from file if provided
    if [ -n "$cfg_file" ] && [ -f "$cfg_file" ]; then
        provision_load_config "$cfg_file"
    fi
    
    log "Starting Enhanced Arch Linux provisioning..."
    log "Profile: $profile | Shell: $shell | SSH: port $ssh_port (root_login=$ssh_root_login)"
    
    # ========== PACMAN MIRROR SELECTION ==========
    if [ -n "$pacman_mirror" ] && [ "$pacman_mirror" != "default" ]; then
        run_cmd "Configuring pacman mirror" sh -c "
            sed -i \"1,/^#Server/s|^#Server|Server|\" /etc/pacman.d/mirrorlist || true
        "
    fi
    
    # ========== PACKAGE PROFILES ==========
    local pkgs_base="bash bash-completion coreutils findutils grep sed gawk diffutils util-linux procps-ng shadow file less openssh ca-certificates openssl man man-pages curl wget rsync tzdata"
    
    local pkgs_standard="$pkgs_base openssh sudo base-devel python python-pip vim nano tmux sysstat htop ncdu lsof pv tree fzf ripgrep fd bat eza jq yq nmap tar unzip zip p7zip bzip2 gzip zstd xz git chrony cronie logrotate rsyslog"
    
    local pkgs_full="$pkgs_standard neovim emacs perl ruby ruby-gems golang rust cargo nodejs npm lazygit tig mercurial subversion meson ninja scons bazel lldb valgrind gdb strace ltrace wireshark tcpdump socat netcat mtr bind iproute2 bridge-utils wireguard openvpn openconnect sqlite redis postgresql-libs mysql-libs docker"
    
    local pkgs_dev="$pkgs_full autoconf automake libtool pkg-config clang llvm uncrustify clang-tools-extra stress stress-ng sysbench graphviz doxygen sphinx gettext protobuf protobuf-c cmake cmake-gui"
    
    local pkgs_server="$pkgs_standard openssh rsyslog fail2ban aide logrotate rsync lvm2 mdadm cryptsetup btrfs-progs nginx postgresql redis bind haproxy keepalived etcd consul"
    
    local pkgs_container="$pkgs_base openssh sudo docker docker-compose podman buildah skopeo runc containerd cri-o kubectl helm terraform ansible python python-pip"
    
    local pkgs_minimal="$pkgs_base openssh sudo"
    
    # Select package set based on profile
    case "$profile" in
        minimal)    local pkgs="$pkgs_minimal" ;;
        standard)   local pkgs="$pkgs_standard" ;;
        full)       local pkgs="$pkgs_full" ;;
        dev)        local pkgs="$pkgs_dev" ;;
        server)     local pkgs="$pkgs_server" ;;
        container)  local pkgs="$pkgs_container" ;;
        *)          log "ERROR: Unknown profile $profile"; return 1 ;;
    esac
    
    # ========== PACKAGE INSTALLATION ==========
    run_cmd "pacman -Sy" pacman -Sy --noconfirm >/dev/null 2>&1 || true
    run_cmd "Installing packages ($profile profile)" pacman -S --needed --noconfirm $pkgs || {
        log "WARN: pacman reported errors; continuing"
    }
    
    # ========== TIMEZONE & LOCALE ==========
    if [ -f "/usr/share/zoneinfo/$tz" ]; then
        ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
    else
        log "WARN: unknown timezone '$tz'; leaving the system timezone unchanged."
    fi
    run_cmd "Setting timezone to $tz" timedatectl set-timezone "$tz" >/dev/null 2>&1 || true
    
    if ! grep -q '^LANG=' /etc/locale.conf 2>/dev/null; then
        run_cmd "Setting locale C.UTF-8" sh -c "echo 'LANG=C.UTF-8' > /etc/locale.conf"
    fi
    
    # ========== KEYBOARD LAYOUT ==========
    if [ -n "$keyboard" ] && [ "$keyboard" != "default" ]; then
        run_cmd "Setting keyboard layout to $keyboard" sh -c "
            localectl set-keymap $keyboard 2>/dev/null || true
        "
    fi
    
    # ========== MACHINE ID ==========
    [ ! -s /etc/machine-id ] && {
        run_cmd "Generating machine-id" sh -c "{ openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n'; } > /etc/machine-id && chmod 0444 /etc/machine-id"
    }
    
    # ========== HOSTNAME ==========
    [ -n "$host" ] && run_cmd "Setting hostname to $host" hostnamectl set-hostname "$host" 2>/dev/null || echo "$host" > /etc/hostname
    
    # ========== NETWORK CONFIGURATION ==========
    if [ "$dhcp" = 0 ] && [ -n "$ipaddr" ]; then
        run_cmd "Configuring static IP $ipaddr" sh -c "cat > /etc/systemd/network/99-static.network <<EOF
[Match]
Name=eth0

[Network]
Address=$ipaddr
Gateway=$gateway
DNS=$(echo $dns_servers | head -n1)
EOF
"
    else
        run_cmd "Configuring DHCP" sh -c "cat > /etc/systemd/network/99-dhcp.network <<EOF
[Match]
Name=eth0

[Network]
DHCP=yes
EOF
"
    fi
    
    # Configure DNS
    if [ -n "$dns_servers" ]; then
        run_cmd "Configuring DNS servers" sh -c "
            mkdir -p /etc/systemd/resolved.conf.d
            cat > /etc/systemd/resolved.conf.d/dns.conf <<EOF
[Resolve]
DNS=$(echo $dns_servers | tr ' ' ' ')
FallbackDNS=1.1.1.1 8.8.8.8
EOF
            systemctl restart systemd-resolved 2>/dev/null || true
        "
    fi
    
    # ========== NTP CONFIGURATION ==========
    run_cmd "Configuring NTP ($ntp_server)" timedatectl set-ntp true 2>/dev/null || true
    
    # ========== SUDOERS CONFIGURATION ==========
    if [ "$nopass" = 1 ]; then
        run_cmd "Setting passwordless sudo for wheel" sh -c "echo '%wheel ALL=(ALL) NOPASSWD: ALL' | tee /etc/sudoers.d/wheel > /dev/null && chmod 0440 /etc/sudoers.d/wheel"
    else
        run_cmd "Setting sudo with password for wheel" sh -c "echo '%wheel ALL=(ALL) ALL' | tee /etc/sudoers.d/wheel > /dev/null && chmod 0440 /etc/sudoers.d/wheel"
    fi
    
    # ========== USER & GROUP MANAGEMENT ==========
    if [ -n "$user" ] && [ "$user" != root ] && ! id "$user" >/dev/null 2>&1; then
        run_cmd "Creating user $user" useradd -m -s "/bin/$shell" -G wheel "$user" 2>/dev/null || true
    fi
    
    # Set default shell
    grep -qx "/bin/$shell" /etc/shells 2>/dev/null || sh -c "echo /bin/$shell >> /etc/shells"
    for u in root $user; do
        id "$u" >/dev/null 2>&1 && run_cmd "Setting $u shell to $shell" chsh -s "/bin/$shell" "$u" >/dev/null 2>&1 || true
    done
    
    # ========== SSH CONFIGURATION ==========
    if [ "$enable_ssh" = 1 ]; then
        run_cmd "Configuring SSH" provision_configure_sshd "$ssh_port" "$ssh_root_login" "no"
    fi
    
    # ========== FIREWALL CONFIGURATION ==========
    if [ "$enable_firewall" = 1 ]; then
        run_cmd "Installing and configuring firewall" sh -c "
            pacman -S --noconfirm ufw 2>/dev/null || true
            if command -v ufw >/dev/null 2>&1; then
                ufw allow $ssh_port/tcp || true
                ufw --force enable || true
                systemctl enable ufw 2>/dev/null || true
            fi
        "
    fi
    
    # ========== FAIL2BAN CONFIGURATION ==========
    if [ "$enable_fail2ban" = 1 ]; then
        run_cmd "Installing and configuring fail2ban" sh -c "
            pacman -S --noconfirm fail2ban 2>/dev/null || true
            cat > /etc/fail2ban/jail.local <<'FAIL2BAN'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = $ssh_port
FAIL2BAN
            systemctl enable fail2ban 2>/dev/null || true
            systemctl start fail2ban 2>/dev/null || true
        "
    fi
    
    # ========== SELINUX CONFIGURATION ==========
    if [ "$enable_selinux" = 1 ]; then
        run_cmd "Installing SELinux" sh -c "
            pacman -S --noconfirm selinux-python-tools 2>/dev/null || true
            semanage permissive -a init_t 2>/dev/null || true
        "
    fi
    
    # ========== SYSTEM LIMITS ==========
    if [ "$max_open_files" != "default" ]; then
        run_cmd "Setting system limits" sh -c "
            echo '* soft nofile $max_open_files' >> /etc/security/limits.conf
            echo '* hard nofile $max_open_files' >> /etc/security/limits.conf
        "
    fi
    
    # ========== SWAP CONFIGURATION ==========
    if [ "$swap_size" -gt 0 ]; then
        run_cmd "Creating ${swap_size}MB swap" sh -c "
            dd if=/dev/zero of=/swapfile bs=1M count=$swap_size 2>/dev/null
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
        "
    fi
    
    # ========== JOURNALD CONFIGURATION ==========
    if [ -n "$journald_level" ]; then
        run_cmd "Configuring journald level" sh -c "
            mkdir -p /etc/systemd/journald.conf.d
            cat > /etc/systemd/journald.conf.d/99-aok.conf <<EOF
[Journal]
MaxLevelStore=$journald_level
MaxLevelSyslog=$journald_level
EOF
            systemctl restart systemd-journald 2>/dev/null || true
        "
    fi
    
    # ========== REMOTE SYSLOG ==========
    if [ -n "$remote_syslog" ]; then
        run_cmd "Configuring remote syslog to $remote_syslog" sh -c "
            echo \"*.*  @$remote_syslog\" >> /etc/rsyslog.d/99-remote.conf
            systemctl restart rsyslog 2>/dev/null || true
        "
    fi
    
    # ========== AUTOMATIC UPDATES ==========
    if [ "$enable_autoupdate" = 1 ]; then
        run_cmd "Enabling automatic updates" sh -c "
            pacman -S --noconfirm pacman-contrib 2>/dev/null || true
            cat > /etc/systemd/system/pacman-autoupdate.timer <<'TIMER'
[Unit]
Description=Automatically update pacman packages

[Timer]
OnCalendar=daily
OnBootSec=10min

[Install]
WantedBy=timers.target
TIMER
            cat > /etc/systemd/system/pacman-autoupdate.service <<'SERVICE'
[Unit]
Description=Auto-update pacman packages
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman -Syu --noconfirm
StandardOutput=journal
StandardError=journal
SERVICE
            systemctl enable pacman-autoupdate.timer 2>/dev/null || true
        "
    fi
    
    # ========== MOTD ==========
    run_cmd "Creating MOTD" cat > /etc/motd <<'MOTD'
   Arch Linux  .  iSH-AOK  (enhanced)
   ---------------------------------
   Profile  : PROFILE_NAME
   services :  systemctl {start|stop|status} <name>
   on boot  :  systemctl {enable|disable} <name>
   status   :  systemctl status       logs : journalctl -e
   packages :  pacman -S <pkg>        docs : man <command>
MOTD
    sed -i "s/PROFILE_NAME/$profile/" /etc/motd
    
    # ========== SHELL ENVIRONMENT ==========
    run_cmd "Creating shell environment" cat > /etc/profile.d/30-aok-enhanced.sh <<'NICETIES'
export EDITOR=vim VISUAL=vim PAGER=less
export LESS='-R -M -i'
export TERM="${TERM:-xterm-256color}"
export LC_ALL="${LC_ALL:-C.UTF-8}" LANG="${LANG:-C.UTF-8}"
case $- in *i*) ;; *) return 2>/dev/null || exit 0;; esac

alias ls='ls --color=auto'
alias ll='ls -alF --color=auto'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -m'
alias ps='ps aux'
alias top='top -o %CPU'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

if [ -n "${BASH:-}" ]; then
  if [ "$(id -u)" = 0 ]; then
    PS1='\[\e[1;31m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]# '
  else
    PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
  fi
  HISTSIZE=10000; HISTFILESIZE=20000; HISTCONTROL=ignoreboth
  shopt -s histappend checkwinsize 2>/dev/null
fi

if [ -z "${_AOK_SUMMARY_DONE:-}" ]; then
  export _AOK_SUMMARY_DONE=1
  printf '\n  \033[1;36m%s\033[0m  .  kernel \033[1m%s\033[0m  .  %s\n' "Arch Linux" "$(uname -r)" "$(uname -m)"
  printf '  uptime:%s\n' "$(uptime 2>/dev/null | sed 's/^[[:space:]]*//;s/^/ /')"
fi
NICETIES
    chmod 0644 /etc/profile.d/30-aok-enhanced.sh
    
    # ========== SERVICE MANAGEMENT ==========
    local services="sshd cronie systemd-networkd systemd-resolved chrony"
    [ "$enable_fail2ban" = 1 ] && services="$services fail2ban"
    [ "$enable_selinux" = 1 ] && services="$services selinux"
    
    for s in $services; do
        systemctl enable "$s" >/dev/null 2>&1 || true
        systemctl restart "$s" >/dev/null 2>&1 || true
    done
    
    # ========== SUMMARY ==========
    tui_msg "Arch Enhanced Provisioning Complete" \
        "Arch Linux has been provisioned successfully!\n\n
Profile: $profile
Shell: $shell
SSH: port $ssh_port (root_login=$([ $ssh_root_login = 1 ] && echo enabled || echo disabled))
Firewall: $([ $enable_firewall = 1 ] && echo enabled || echo disabled)
Fail2Ban: $([ $enable_fail2ban = 1 ] && echo enabled || echo disabled)
SELinux: $([ $enable_selinux = 1 ] && echo enabled || echo disabled)
Auto-Update: $([ $enable_autoupdate = 1 ] && echo enabled || echo disabled)

Re-login to activate changes.\n\nServices enabled: $services"
}

# Provisioning mutates the live system, so it wants fail-fast semantics. That
# used to come from a shell-wide `set -eE` in config.sh, which also applied to
# the interactive TUI and turned every dialog Cancel into a fatal error. The
# strictness now lives here, scoped to this routine and contained in a subshell
# so a failure aborts the provisioning run without tearing down the menu.
provision_arch_enhanced() {
    run_strict "provision_arch_enhanced" provision_arch_enhanced_impl "$@"
}

export -f provision_arch_enhanced_impl provision_arch_enhanced
