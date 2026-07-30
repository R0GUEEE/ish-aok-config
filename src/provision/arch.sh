#!/bin/bash
# systui — Provision Arch Linux
PROV_RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$PROV_RUNTIME_DIR/runtime.sh" ] && . "$PROV_RUNTIME_DIR/runtime.sh"

provision_arch_impl() {
    provision_require_family archlinux || return $?
    local tz="$1" user="$2" host="$3" nopass="$4"
    
    log "Starting Arch Linux provisioning..."
    
    # iSH workarounds
    [ -e /dev/fd ] || ln -s /proc/self/fd /dev/fd
    [ -e /dev/stdin ] || ln -s /proc/self/fd/0 /dev/stdin
    [ -e /dev/stdout ] || ln -s /proc/self/fd/1 /dev/stdout
    [ -e /dev/stderr ] || ln -s /proc/self/fd/2 /dev/stderr
    
    if [ "$(stat -c %u /usr 2>/dev/null)" = 501 ]; then
        log "Repairing uid-501 ownership..."
        chown -R --from=501 0:0 / 2>/dev/null || true
    fi
    
    # `pacman -Sy` followed by `-S` is the partial-upgrade pattern that breaks
    # Arch installs: it refreshes the sync database without upgrading the
    # installed packages, so the next install pulls in libraries built against
    # newer versions than the ones on disk. -Syu keeps the two in step.
    run_cmd "pacman -Syu" pacman -Syu --noconfirm >/dev/null 2>&1 || true
    
    local pkgs="bash bash-completion cmake coreutils findutils grep sed gawk diffutils util-linux procps-ng shadow file less base-devel gcc make openssh sudo syslog-ng chrony cronie tzdata ca-certificates openssl man-db man-pages curl wget rsync bind git strace gdb linux-headers python python-pip vim neovim nano tmux htop btop ncdu lsof pv tree mc fzf ripgrep fd bat eza jq yq most w3m lynx nmap socat openbsd-netcat mtr tar unzip zip p7zip bzip2 gzip zstd xz fastfetch figlet ncurses lazygit"
    
    run_cmd "Installing packages" pacman -S --noconfirm --needed $pkgs || true
    
    if [ -f "/usr/share/zoneinfo/$tz" ]; then
        ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
    else
        log "WARN: unknown timezone '$tz'; leaving the system timezone unchanged."
    fi
    echo "$tz" > /etc/timezone
    
    if ! grep -q '^LANG=' /etc/environment 2>/dev/null; then
        printf 'LANG=C.UTF-8\nLC_ALL=C.UTF-8\n' >> /etc/environment
    fi
    
    [ ! -s /etc/machine-id ] && {
        run_cmd "Generating machine-id" sh -c "{ openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n'; } > /etc/machine-id && chmod 0444 /etc/machine-id"
    }
    
    [ -n "$host" ] && run_cmd "Setting hostname to $host" sh -c "echo '$host' > /etc/hostname && hostname '$host' 2>/dev/null || true"
    
    if [ "$nopass" = 1 ]; then
        run_cmd "Setting passwordless sudo for wheel" sh -c "echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel && chmod 0440 /etc/sudoers.d/wheel"
    else
        run_cmd "Setting sudo with password for wheel" sh -c "echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel && chmod 0440 /etc/sudoers.d/wheel"
    fi
    
    if [ -n "$user" ] && [ "$user" != root ] && [ "$user" != alarm ] && ! id "$user" >/dev/null 2>&1 && id alarm >/dev/null 2>&1; then
        if usermod -l "$user" -d "/home/$user" -m alarm 2>/dev/null; then
            getent group alarm >/dev/null 2>&1 && groupmod -n "$user" alarm 2>/dev/null
            sed -i "s/\balarm\b/$user/g" /etc/group /etc/gshadow 2>/dev/null
            log "Renamed 'alarm' account to '$user'"
        fi
    fi
    
    if [ -n "$user" ] && [ "$user" != root ] && ! id "$user" >/dev/null 2>&1; then
        run_cmd "Creating user $user" useradd -m -s /bin/bash "$user" 2>/dev/null
    fi
    
    if [ -n "$user" ] && id "$user" >/dev/null 2>&1; then
        id -nG "$user" | tr ' ' '\n' | grep -qx wheel || run_cmd "Adding $user to wheel" usermod -aG wheel "$user" 2>/dev/null || true
    fi
    
    grep -qx /bin/bash /etc/shells 2>/dev/null || sh -c "echo /bin/bash >> /etc/shells"
    for u in root $user; do
        id "$u" >/dev/null 2>&1 && usermod -s /bin/bash "$u" 2>/dev/null || true
    done
    
    run_cmd "Creating MOTD" cat > /etc/motd <<'MOTD'
   Arch Linux  .  iSH-AOK  (terminal-only userspace)
   --------------------------------------------------
   services :  systemctl {start|stop|status} <name>
   on boot  :  systemctl {enable|disable} <name>
   status   :  systemctl status           logs : journalctl -e
   time     :  chronyc tracking           docs : man <command>
   --------------------------------------------------
MOTD
    
    run_cmd "Creating shell niceties" cat > /etc/profile.d/30-aok-niceties.sh <<'NICETIES'
export EDITOR=vim VISUAL=vim PAGER=less
export LESS='-R -M -i'
export TERM="${TERM:-xterm-256color}"
export LC_ALL="${LC_ALL:-C.UTF-8}" LANG="${LANG:-C.UTF-8}"
case $- in *i*) ;; *) return 2>/dev/null || exit 0;; esac
alias ls='ls --color=auto'
alias ll='ls -alF --color=auto'
alias grep='grep --color=auto'
alias df='df -h'
alias free='free -m'
alias ..='cd ..'
if [ -n "${BASH:-}" ]; then
  if [ "$(id -u)" = 0 ]; then
    PS1='\[\e[1;31m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]# '
  else
    PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
  fi
  HISTSIZE=5000; HISTFILESIZE=10000; HISTCONTROL=ignoreboth
  shopt -s histappend checkwinsize 2>/dev/null
fi
if [ -z "${_AOK_SUMMARY_DONE:-}" ]; then
  export _AOK_SUMMARY_DONE=1
  printf '\n  \033[1;36m%s\033[0m  .  kernel \033[1m%s\033[0m  .  %s\n' "Arch Linux" "$(uname -r)" "$(uname -m)"
  printf '  uptime:%s\n' "$(uptime 2>/dev/null | sed 's/^[[:space:]]*//;s/^/ /')"
  printf '  disk /: %s   mem: %s\n\n' "$(command df -h / 2>/dev/null | awk 'NR==2{print $3" / "$2" ("$5")"}')" "$(command free -m 2>/dev/null | awk '/^Mem:/{print $3"M / "$2"M"}')"
fi
NICETIES
    chmod 0644 /etc/profile.d/30-aok-niceties.sh
    
    provision_service_enable_start sshd
    provision_service_enable_start syslog-ng
    provision_service_enable_start chronyd
    provision_service_enable_start cronie crond
    
    tui_msg "Arch Provisioning Complete" "Arch Linux has been provisioned successfully.\n\nRe-login to activate bash + MOTD."
}

# Provisioning mutates the live system, so it wants fail-fast semantics. That
# used to come from a shell-wide `set -eE` in config.sh, which also applied to
# the interactive TUI and turned every dialog Cancel into a fatal error. The
# strictness now lives here, scoped to this routine and contained in a subshell
# so a failure aborts the provisioning run without tearing down the menu.
provision_arch() {
    run_strict "provision_arch" provision_arch_impl "$@"
}

export -f provision_arch_impl provision_arch
