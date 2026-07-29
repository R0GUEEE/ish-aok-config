#!/bin/bash
###############################################################################
# systui — Enhanced Debian 12+ Provisioning
#
# Features:
#   • Advanced network configuration (static IP, DNS, gateway)
#   • Security hardening (SSH, firewall, fail2ban, AppArmor)
#   • Package profiles (minimal, standard, full, dev, server, container)
#   • Shell preferences (bash, zsh, fish, ksh)
#   • NTP/time synchronization options
#   • Disk optimization and swap configuration
#   • Automatic updates and security patches
#   • System limits and performance tuning
#   • Logging configuration (journald levels, remote logging)
#   • Additional user/group management
###############################################################################

provision_debian_enhanced() {
    local cfg_file="$1"
    
    # Default configurations
    local tz="UTC"
    local user="debian"
    local host="debian-minisys"
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
    local enable_apparmor=0
    local max_open_files=65536
    local remote_syslog=""
    local apt_mirror=""
    
    # Load configuration from file if provided
    if [ -n "$cfg_file" ] && [ -f "$cfg_file" ]; then
        # shellcheck source=/dev/null
        source "$cfg_file" || log "WARN: Failed to source config file $cfg_file"
    fi
    
    log "Starting Enhanced Debian Linux provisioning..."
    log "Profile: $profile | Shell: $shell | SSH: port $ssh_port (root_login=$ssh_root_login)"
    
    export DEBIAN_FRONTEND=noninteractive
    
    # ========== APT MIRROR SELECTION ==========
    if [ -n "$apt_mirror" ] && [ "$apt_mirror" != "default" ]; then
        run_cmd "Configuring APT mirror" sh -c "
            sed -i \"s|deb.debian.org|$apt_mirror|g\" /etc/apt/sources.list
        "
    fi
    
    # ========== TIMEZONE & LOCALE ==========
    ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime 2>/dev/null || true
    printf '%s\n' "$tz" > /etc/timezone
    
    # ========== KEYBOARD LAYOUT ==========
    if [ -n "$keyboard" ] && [ "$keyboard" != "default" ]; then
        run_cmd "Setting keyboard layout to $keyboard" sh -c "
            sed -i \"s/XKBLAYOUT=.*/XKBLAYOUT=$keyboard/\" /etc/default/keyboard 2>/dev/null || true
        "
    fi
    
    # ========== PACKAGE PROFILES ==========
    local pkgs_base="bash bash-completion coreutils findutils grep sed gawk diffutils util-linux bsdextrautils procps passwd file less openssh-client ca-certificates openssl man-db manpages curl wget rsync tzdata locales"
    
    local pkgs_standard="$pkgs_base openssh-server sudo build-essential python3 python3-pip python3-venv vim nano tmux sysstat htop ncdu lsof pv tree fzf ripgrep fd-find bat eza jq yq nmap tar unzip zip p7zip-full bzip2 gzip zstd xz-utils git chrony cron logrotate rsyslog"
    
    local pkgs_full="$pkgs_standard neovim emacs perl ruby ruby-dev golang rustc cargo nodejs npm lazygit tig mercurial subversion meson ninja-build scons bazel lldb valgrind gdb strace ltrace wireshark tcpdump socat netcat-openbsd iperf3 mtr bind9-dnsutils iproute2 bridge-utils wireguard openvpn openconnect sqlite3 redis-tools postgresql-client mysql-client docker.io"
    
    local pkgs_dev="$pkgs_full autoconf automake libtool pkg-config clang llvm uncrustify clang-format stress stress-ng sysbench graphviz doxygen sphinx-common gettext protobuf-compiler libprotobuf-dev cmake cmake-gui"
    
    local pkgs_server="$pkgs_standard openssh-server rsyslog fail2ban aide rkhunter lylis logrotate rsync lvm2 mdadm cryptsetup btrfs-progs nginx postgresql redis-server bind9 haproxy keepalived etcd consul"
    
    local pkgs_container="$pkgs_base openssh-server docker.io docker-compose podman buildah skopeo runc containerd cri-o kubectl helm terraform ansible python3 python3-pip"
    
    local pkgs_minimal="$pkgs_base openssh-server openssh-client sudo"
    
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
    run_cmd "apt-get update" apt-get update >/dev/null 2>&1 || true
    
    if apt-get install -y --no-install-recommends $pkgs; then
        log "Packages installed ($profile profile)"
    else
        log "Batch install had errors; retrying package-by-package"
        for p in $pkgs; do
            apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1 || true
        done
    fi
    apt-get clean >/dev/null 2>&1 || true
    
    # Fix binary name differences in Debian
    command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1 && ln -sf "$(command -v batcat)" /usr/local/bin/bat
    command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1 && ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    
    # ========== LOCALE CONFIGURATION ==========
    printf 'LANG=C.UTF-8\n' > /etc/default/locale
    if ! grep -q '^LANG=' /etc/environment 2>/dev/null; then
        printf 'LANG=C.UTF-8\nLC_ALL=C.UTF-8\n' >> /etc/environment
    fi
    update-locale LANG=C.UTF-8 2>/dev/null || true
    
    # ========== MACHINE ID ==========
    [ ! -s /etc/machine-id ] && run_cmd "Generating machine-id" sh -c "{ openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n'; } > /etc/machine-id && chmod 0444 /etc/machine-id"
    
    # ========== HOSTNAME ==========
    [ -n "$host" ] && run_cmd "Setting hostname to $host" sh -c "echo '$host' > /etc/hostname && hostname '$host' 2>/dev/null || true && printf '127.0.1.1\t%s\n' '$host' >> /etc/hosts"
    
    # ========== NETWORK CONFIGURATION ==========
    if [ "$dhcp" = 0 ] && [ -n "$ipaddr" ]; then
        run_cmd "Configuring static IP $ipaddr" sh -c "cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address $ipaddr
    gateway $gateway
    dns-nameservers $dns_servers
EOF
"
    else
        run_cmd "Configuring DHCP" sh -c "cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF
"
    fi
    
    # Configure DNS
    if [ -n "$dns_servers" ]; then
        run_cmd "Configuring DNS servers" sh -c "
            mkdir -p /etc/resolv.conf.d
            { for dns in $dns_servers; do echo \"nameserver \$dns\"; done; } > /etc/resolv.conf.d/custom
        "
    fi
    
    # ========== NTP CONFIGURATION ==========
    run_cmd "Configuring NTP ($ntp_server)" sh -c "
        sed -i 's/^pool .*/pool $ntp_server iburst/' /etc/chrony/chrony.conf || true
    "
    
    # ========== SUDOERS CONFIGURATION ==========
    getent group sudo >/dev/null 2>&1 || groupadd sudo 2>/dev/null || true
    if [ "$nopass" = 1 ]; then
        run_cmd "Setting passwordless sudo" sh -c "echo '%sudo ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/aok-sudo && chmod 0440 /etc/sudoers.d/aok-sudo"
    else
        run_cmd "Setting sudo with password" sh -c "echo '%sudo ALL=(ALL:ALL) ALL' > /etc/sudoers.d/aok-sudo && chmod 0440 /etc/sudoers.d/aok-sudo"
    fi
    
    # ========== USER & GROUP MANAGEMENT ==========
    if [ -n "$user" ] && [ "$user" != root ] && ! id "$user" >/dev/null 2>&1; then
        run_cmd "Creating user $user" adduser --disabled-password --gecos "" --shell "/bin/$shell" "$user" >/dev/null 2>&1 || useradd -m -s "/bin/$shell" "$user" 2>/dev/null
    fi
    
    if [ -n "$user" ] && id "$user" >/dev/null 2>&1; then
        id -nG "$user" | tr ' ' '\n' | grep -qx sudo || run_cmd "Adding $user to sudo group" adduser "$user" sudo >/dev/null 2>&1 || true
    fi
    
    # Set default shell
    grep -qx "/bin/$shell" /etc/shells 2>/dev/null || sh -c "echo /bin/$shell >> /etc/shells"
    for u in root $user; do
        id "$u" >/dev/null 2>&1 && chsh -s "/bin/$shell" "$u" >/dev/null 2>&1 || usermod -s "/bin/$shell" "$u" 2>/dev/null || true
    done
    
    # ========== SSH CONFIGURATION ==========
    if [ "$enable_ssh" = 1 ]; then
        run_cmd "Configuring SSH" sh -c "
            sed -i 's/^#Port .*/Port $ssh_port/' /etc/ssh/sshd_config
            sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
            sed -i 's/^PermitRootLogin .*/PermitRootLogin $([ $ssh_root_login = 1 ] && echo yes || echo no)/' /etc/ssh/sshd_config
            sed -i 's/^#X11Forwarding .*/X11Forwarding no/' /etc/ssh/sshd_config
            sed -i 's/^#StrictModes .*/StrictModes yes/' /etc/ssh/sshd_config
            sed -i 's/^#ClientAliveInterval .*/ClientAliveInterval 300/' /etc/ssh/sshd_config
        "
    fi
    
    # ========== FIREWALL CONFIGURATION ==========
    if [ "$enable_firewall" = 1 ]; then
        run_cmd "Installing and configuring firewall" sh -c "
            apt-get install -y --no-install-recommends ufw >/dev/null 2>&1 || true
            if command -v ufw >/dev/null 2>&1; then
                ufw allow $ssh_port/tcp || true
                ufw --force enable || true
            fi
        "
    fi
    
    # ========== FAIL2BAN CONFIGURATION ==========
    if [ "$enable_fail2ban" = 1 ]; then
        run_cmd "Installing and configuring fail2ban" sh -c "
            apt-get install -y --no-install-recommends fail2ban >/dev/null 2>&1 || true
            cat > /etc/fail2ban/jail.local <<'FAIL2BAN'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = $ssh_port
filter = sshd
logpath = /var/log/auth.log
FAIL2BAN
            systemctl restart fail2ban 2>/dev/null || true
        "
    fi
    
    # ========== APPARMOR CONFIGURATION ==========
    if [ "$enable_apparmor" = 1 ]; then
        run_cmd "Enabling AppArmor" sh -c "
            systemctl enable apparmor 2>/dev/null || true
            systemctl start apparmor 2>/dev/null || true
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
        run_cmd "Enabling automatic security updates" sh -c "
            apt-get install -y --no-install-recommends unattended-upgrades apt-listchanges >/dev/null 2>&1 || true
            dpkg-reconfigure -plow unattended-upgrades 2>/dev/null || true
        "
    fi
    
    # ========== MOTD ==========
    run_cmd "Creating MOTD" cat > /etc/motd <<'MOTD'
   Debian GNU/Linux 12+  .  iSH-AOK  (enhanced)
   -----------------------------------------
   Profile  : PROFILE_NAME
   services :  systemctl {start|stop|status} <name>
   on boot  :  systemctl {enable|disable} <name>
   status   :  systemctl status       logs : journalctl -e
   time     :  chronyc tracking       docs : man <command>
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
  printf '\n  \033[1;36m%s\033[0m  .  kernel \033[1m%s\033[0m  .  %s\n' "Debian GNU/Linux" "$(uname -r)" "$(uname -m)"
  printf '  uptime:%s\n' "$(uptime 2>/dev/null | sed 's/^[[:space:]]*//;s/^/ /')"
fi
NICETIES
    chmod 0644 /etc/profile.d/30-aok-enhanced.sh
    
    # ========== SERVICE MANAGEMENT ==========
    local services="ssh rsyslog cron chrony"
    [ "$enable_fail2ban" = 1 ] && services="$services fail2ban"
    [ "$enable_apparmor" = 1 ] && services="$services apparmor"
    
    for s in $services; do
        systemctl enable "$s" >/dev/null 2>&1 || true
        systemctl restart "$s" >/dev/null 2>&1 || true
    done
    
    # ========== SUMMARY ==========
    tui_msg "Debian Enhanced Provisioning Complete" \
        "Debian has been provisioned successfully!\n\n
Profile: $profile
Shell: $shell
SSH: port $ssh_port (root_login=$([ $ssh_root_login = 1 ] && echo enabled || echo disabled))
Firewall: $([ $enable_firewall = 1 ] && echo enabled || echo disabled)
Fail2Ban: $([ $enable_fail2ban = 1 ] && echo enabled || echo disabled)
AppArmor: $([ $enable_apparmor = 1 ] && echo enabled || echo disabled)
Auto-Update: $([ $enable_autoupdate = 1 ] && echo enabled || echo disabled)

Re-login to activate changes.\n\nServices enabled: $services"
}

export -f provision_debian_enhanced
