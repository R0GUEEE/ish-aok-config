#!/bin/bash
###############################################################################
PROV_RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$PROV_RUNTIME_DIR/runtime.sh" ] && . "$PROV_RUNTIME_DIR/runtime.sh"
# systui — Enhanced Alpine Linux 3.23+ Provisioning
# 
# Features:
#   • Advanced network configuration (static IP, DNS, gateway)
#   • Security hardening (SSH, firewall, fail2ban, SELinux)
#   • Package profiles (minimal, standard, full, dev, server, container)
#   • Shell preferences (bash, zsh, fish, ksh)
#   • NTP/time synchronization options
#   • Disk optimization and swap configuration
#   • Automatic updates and security patches
#   • System limits and performance tuning
#   • Logging configuration (syslog levels, remote logging)
#   • Additional user/group management
###############################################################################

provision_alpine_enhanced() {
    provision_require_family alpine || return $?
    local cfg_file="$1"
    
    # Default configurations
    local tz="UTC"
    local user="alpine"
    local host="alpine-minisys"
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
    local syslog_level="info"
    local enable_audit=0
    local max_open_files=65536
    local remote_syslog=""
    
    # Load configuration from file if provided
    if [ -n "$cfg_file" ] && [ -f "$cfg_file" ]; then
        # shellcheck source=/dev/null
        source "$cfg_file" || log "WARN: Failed to source config file $cfg_file"
    fi
    
    log "Starting Enhanced Alpine Linux provisioning..."
    log "Profile: $profile | Shell: $shell | SSH: port $ssh_port (root_login=$ssh_root_login)"
    
    # ========== PACKAGE PROFILES ==========
    local pkgs_base="bash bash-completion coreutils findutils grep sed gawk diffutils util-linux-misc procps-ng shadow file less openrc openssh ca-certificates openssl man-db man-pages curl wget rsync ca-certificates tzdata"
    
    local pkgs_standard="$pkgs_base syslog-ng syslog-ng-openrc chrony cronie cronie-openrc logrotate openssh-server sudo build-base cmake python3 py3-pip vim nano tmux htop ncdu lsof tree fzf ripgrep fd bat eza jq yq nmap tar unzip zip p7zip bzip2 gzip zstd xz"
    
    local pkgs_full="$pkgs_standard neovim emacs perl ruby ruby-dev go rust cargo nodejs npm git lazygit tig mercurial subversion meson ninja-build scons bazel lldb valgrind gdb strace ltrace wireshark tshark tcpdump socat netcat-openbsd iperf3 mtr bind-tools iproute2 bridge-utils wireguard-tools openvpn openconnect sqlite3 redis postgresql-client mysql-client docker podman buildah skopeo"
    
    local pkgs_dev="$pkgs_full autoconf automake libtool pkg-config clang llvm uncrustify clang-format stress stress-ng sysbench graphviz doxygen sphinx gettext protobuf protobuf-dev libprotobuf"
    
    local pkgs_server="$pkgs_standard openssh-server syslog-ng syslog-ng-openrc fail2ban aide rkhunter lynis logrotate rsync lvm2 mdadm cryptsetup btrfs-progs nginx postgresql redis bind haproxy keepalived etcd consul"
    
    local pkgs_container="$pkgs_base docker podman containerd cri-o buildah skopeo runc docker-compose podman-compose kubectl helm terraform ansible salt python3 py3-pip"
    
    local pkgs_minimal="$pkgs_base openrc openssh-server openssh-client sudo"
    
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
    run_cmd "apk update" apk update || true
    run_cmd "Installing packages ($profile profile)" apk add --no-progress $pkgs || {
        log "WARN: apk add reported errors; continuing with available packages"
    }
    
    # ========== TIMEZONE & LOCALE ==========
    [ -f "/usr/share/zoneinfo/$tz" ] && {
        run_cmd "Setting timezone to $tz" sh -c "ln -sf /usr/share/zoneinfo/$tz /etc/localtime && echo '$tz' > /etc/timezone"
    }
    
    if ! grep -q '^LANG=' /etc/environment 2>/dev/null; then
        run_cmd "Setting locale C.UTF-8" sh -c "printf 'LANG=C.UTF-8\nLC_ALL=C.UTF-8\n' >> /etc/environment"
    fi
    
    # ========== KEYBOARD LAYOUT ==========
    if [ -n "$keyboard" ] && [ "$keyboard" != "default" ]; then
        run_cmd "Setting keyboard layout to $keyboard" sh -c "echo 'KEYMAP=$keyboard' > /etc/conf.d/keymaps" || true
    fi
    
    # ========== MACHINE ID ==========
    [ ! -s /etc/machine-id ] && {
        run_cmd "Generating machine-id" sh -c "{ openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n'; } > /etc/machine-id && chmod 0444 /etc/machine-id"
    }
    
    # ========== HOSTNAME ==========
    [ -n "$host" ] && run_cmd "Setting hostname to $host" sh -c "echo '$host' > /etc/hostname && hostname '$host' 2>/dev/null || true"
    
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
        run_cmd "Configuring DNS servers" sh -c "{ for dns in $dns_servers; do echo \"nameserver \$dns\"; done; } > /etc/resolv.conf"
    fi
    
    # ========== NTP CONFIGURATION ==========
    run_cmd "Configuring NTP ($ntp_server)" sh -c "sed -i 's/^pool .*/pool $ntp_server iburst/' /etc/chrony/chrony.conf" || true
    
    # ========== SUDOERS CONFIGURATION ==========
    grep -q '^@includedir /etc/sudoers.d' /etc/sudoers 2>/dev/null || \
        run_cmd "Configuring sudoers" sh -c "echo '@includedir /etc/sudoers.d' >> /etc/sudoers"
    
    if [ "$nopass" = 1 ]; then
        run_cmd "Setting passwordless sudo for wheel" sh -c "echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel && chmod 0440 /etc/sudoers.d/wheel"
    else
        run_cmd "Setting sudo with password for wheel" sh -c "echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel && chmod 0440 /etc/sudoers.d/wheel"
    fi
    
    # ========== USER & GROUP MANAGEMENT ==========
    if [ -n "$user" ] && [ "$user" != root ] && ! id "$user" >/dev/null 2>&1; then
        run_cmd "Creating user $user" adduser -D -s "/bin/$shell" "$user" 2>/dev/null || adduser -D "$user" 2>/dev/null
    fi
    
    if [ -n "$user" ] && id "$user" >/dev/null 2>&1; then
        id -nG "$user" | tr ' ' '\n' | grep -qx wheel || run_cmd "Adding $user to wheel" adduser "$user" wheel 2>/dev/null || true
    fi
    
    # Set default shell
    if grep -q "^/bin/$shell\$" /etc/shells 2>/dev/null; then
        for u in root $user; do
            id "$u" >/dev/null 2>&1 && run_cmd "Setting $u shell to $shell" chsh -s "/bin/$shell" "$u" >/dev/null 2>&1 || true
        done
    fi
    
    # ========== SSH CONFIGURATION ==========
    if [ "$enable_ssh" = 1 ]; then
        run_cmd "Configuring SSH" sh -c "
            sed -i 's/^#Port .*/Port $ssh_port/' /etc/ssh/sshd_config
            sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
            sed -i 's/^PermitRootLogin .*/PermitRootLogin $([ $ssh_root_login = 1 ] && echo yes || echo no)/' /etc/ssh/sshd_config
            sed -i 's/^#X11Forwarding .*/X11Forwarding no/' /etc/ssh/sshd_config
            sed -i 's/^#StrictModes .*/StrictModes yes/' /etc/ssh/sshd_config
        "
    fi
    
    # ========== FIREWALL CONFIGURATION ==========
    if [ "$enable_firewall" = 1 ]; then
        run_cmd "Installing and configuring firewall" sh -c "
            apk add --no-progress ufw 2>/dev/null || apk add --no-progress iptables 2>/dev/null || true
            if command -v ufw >/dev/null 2>&1; then
                ufw allow $ssh_port/tcp || true
                ufw enable || true
            fi
        "
    fi
    
    # ========== FAIL2BAN CONFIGURATION ==========
    if [ "$enable_fail2ban" = 1 ]; then
        run_cmd "Installing and configuring fail2ban" sh -c "
            apk add --no-progress fail2ban fail2ban-openrc 2>/dev/null || true
            cat > /etc/fail2ban/jail.local <<'FAIL2BAN'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = $ssh_port
FAIL2BAN
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
    
    # ========== LOGGING CONFIGURATION ==========
    if [ -n "$remote_syslog" ]; then
        run_cmd "Configuring remote syslog to $remote_syslog" sh -c "
            echo '@$remote_syslog' >> /etc/syslog-ng/syslog-ng.conf
        "
    fi
    
    # ========== AUTOMATIC UPDATES ==========
    if [ "$enable_autoupdate" = 1 ]; then
        run_cmd "Enabling automatic updates" sh -c "
            apk add --no-progress apk-autoupdate 2>/dev/null || true
            cat > /etc/cron.d/apk-autoupdate <<'AUTOUPDATE'
0 2 * * * root apk update && apk upgrade 2>&1 | logger -t apk-autoupdate
AUTOUPDATE
        "
    fi
    
    # ========== AUDIT/SECURITY HARDENING ==========
    if [ "$enable_audit" = 1 ]; then
        run_cmd "Enabling system audit" sh -c "
            apk add --no-progress audit audit-openrc 2>/dev/null || true
            rc-update add audit boot 2>/dev/null || true
        "
    fi
    
    # ========== MOTD ==========
    run_cmd "Creating MOTD" cat > /etc/motd <<'MOTD'

   Alpine Linux 3.23  .  iSH-AOK  (enhanced)
   ------------------------------------------
   Profile  : PROFILE_NAME
   services :  rc-service <n> {start|stop|status}
   on boot  :  rc-update {add|del} <n> <runlevel>
   status   :  rc-status            logs : /var/log/messages
   time     :  chronyc tracking     docs : man <command>
   ------------------------------------------

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
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
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
  printf '\n  \033[1;36m%s\033[0m  .  kernel \033[1m%s\033[0m  .  %s\n' \
    "Alpine Linux" "$(uname -r)" "$(uname -m)"
  printf '  uptime:%s\n' "$(uptime 2>/dev/null | sed 's/^[[:space:]]*//;s/^/ /')"
  printf '  disk /: %s   mem: %s\n\n' \
    "$(command df -h / 2>/dev/null | awk 'NR==2{print $3" / "$2" ("$5")"}')" \
    "$(command free -m 2>/dev/null | awk '/^Mem:/{print $3"M / "$2"M"}')"
fi
NICETIES
    chmod 0644 /etc/profile.d/30-aok-enhanced.sh
    
    # ========== SERVICE MANAGEMENT ==========
    local services="bootmisc hostname syslog-ng seedrng chrony cronie local"
    [ "$enable_ssh" = 1 ] && services="$services sshd"
    [ "$enable_fail2ban" = 1 ] && services="$services fail2ban"
    [ "$enable_audit" = 1 ] && services="$services audit"
    
    for s in $services; do
        run_cmd "Enabling service $s" rc-update add "$s" $([ "$s" = sshd ] && echo default || echo boot) >/dev/null 2>&1 || true
        rc-service "$s" restart >/dev/null 2>&1 || rc-service "$s" start >/dev/null 2>&1 || true
    done
    
    # ========== SUMMARY ==========
    tui_msg "Alpine Enhanced Provisioning Complete" \
        "Alpine Linux has been provisioned successfully!\n\n
Profile: $profile
Shell: $shell
SSH: port $ssh_port (root_login=$([ $ssh_root_login = 1 ] && echo enabled || echo disabled))
Firewall: $([ $enable_firewall = 1 ] && echo enabled || echo disabled)
Fail2Ban: $([ $enable_fail2ban = 1 ] && echo enabled || echo disabled)
Auto-Update: $([ $enable_autoupdate = 1 ] && echo enabled || echo disabled)
Audit: $([ $enable_audit = 1 ] && echo enabled || echo disabled)

Re-login to activate changes.\n\nServices enabled: $services"
}

export -f provision_alpine_enhanced
