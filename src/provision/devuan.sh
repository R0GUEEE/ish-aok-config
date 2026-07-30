#!/bin/bash
# systui — Provision Devuan 6+
PROV_RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$PROV_RUNTIME_DIR/runtime.sh" ] && . "$PROV_RUNTIME_DIR/runtime.sh"

provision_devuan_impl() {
    provision_require_family devuan || return $?
    local tz="$1" user="$2" host="$3" nopass="$4"
    
    log "Starting Devuan Linux provisioning..."
    export DEBIAN_FRONTEND=noninteractive
    
    # Validate before committing: an unknown zone previously produced a
    # dangling /etc/localtime symlink plus an /etc/timezone that disagreed with
    # it, with the error suppressed by `|| true`.
    if [ -f "/usr/share/zoneinfo/$tz" ]; then
        ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
        printf '%s\n' "$tz" > /etc/timezone
    else
        log "WARN: unknown timezone '$tz'; leaving the system timezone unchanged."
    fi
    run_cmd "apt-get update" apt-get update >/dev/null 2>&1 || true
    
    local pkgs="bash bash-completion cmake coreutils findutils grep sed gawk diffutils util-linux bsdextrautils procps passwd adduser file less sysvinit-core locales openssh-client openssh-server sudo rsyslog iputils-ping wtmpdb chrony cron logrotate tzdata ca-certificates openssl man-db manpages curl wget rsync bind9-dnsutils iproute2 git strace build-essential gdb python3 python3-pip python3-venv vim neovim nano tmux sysstat htop btop ncdu lsof pv tree mc fzf ripgrep fd-find bat eza jq most w3m lynx nmap socat netcat-openbsd mtr-tiny tar unzip zip p7zip-full bzip2 gzip zstd xz-utils fastfetch figlet ncurses-bin ncurses-term"
    
    if apt-get install -y --no-install-recommends $pkgs; then
        log "Packages installed"
    else
        log "Batch install failed; retrying"
        for p in $pkgs; do
            apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1 || true
        done
    fi
    apt-get clean >/dev/null 2>&1 || true
    
    command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1 && ln -sf "$(command -v batcat)" /usr/local/bin/bat
    command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1 && ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    
    printf 'LANG=C.UTF-8\n' > /etc/default/locale
    if ! grep -q '^LANG=' /etc/environment 2>/dev/null; then
        printf 'LANG=C.UTF-8\nLC_ALL=C.UTF-8\n' >> /etc/environment
    fi
    update-locale LANG=C.UTF-8 2>/dev/null || true
    
    [ ! -s /etc/machine-id ] && run_cmd "Generating machine-id" sh -c "{ openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n'; } > /etc/machine-id && chmod 0444 /etc/machine-id"
    
    [ -n "$host" ] && run_cmd "Setting hostname to $host" sh -c "echo '$host' > /etc/hostname && hostname '$host' 2>/dev/null || true && printf '127.0.1.1\t%s\n' '$host' >> /etc/hosts"
    
    getent group sudo >/dev/null 2>&1 || groupadd sudo 2>/dev/null || true
    if [ "$nopass" = 1 ]; then
        run_cmd "Setting passwordless sudo" sh -c "echo '%sudo ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/aok-sudo && chmod 0440 /etc/sudoers.d/aok-sudo"
    else
        run_cmd "Setting sudo with password" sh -c "echo '%sudo ALL=(ALL:ALL) ALL' > /etc/sudoers.d/aok-sudo && chmod 0440 /etc/sudoers.d/aok-sudo"
    fi
    
    if [ -n "$user" ] && [ "$user" != root ] && ! id "$user" >/dev/null 2>&1; then
        run_cmd "Creating user $user" adduser --disabled-password --gecos "" --shell /bin/bash "$user" >/dev/null 2>&1 || useradd -m -s /bin/bash "$user" 2>/dev/null
    fi
    
    if [ -n "$user" ] && id "$user" >/dev/null 2>&1; then
        id -nG "$user" | tr ' ' '\n' | grep -qx sudo || run_cmd "Adding $user to sudo group" adduser "$user" sudo >/dev/null 2>&1 || true
    fi
    
    grep -qx /bin/bash /etc/shells 2>/dev/null || sh -c "echo /bin/bash >> /etc/shells"
    for u in root $user; do
        id "$u" >/dev/null 2>&1 && chsh -s /bin/bash "$u" >/dev/null 2>&1 || usermod -s /bin/bash "$u" 2>/dev/null || true
    done
    
    run_cmd "Creating MOTD" cat > /etc/motd <<'MOTD'
   Devuan GNU/Linux 6 (Excalibur)  .  iSH-AOK
   -------------------------------------------
   services :  service <n> {start|stop|status}
   on boot  :  update-rc.d <n> {enable|disable}
   status   :  service --status-all logs : /var/log/syslog
   time     :  chronyc tracking     docs : man <command>
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
  printf '\n  \033[1;36m%s\033[0m  .  kernel \033[1m%s\033[0m  .  %s\n' "Devuan GNU/Linux" "$(uname -r)" "$(uname -m)"
  printf '  uptime:%s\n' "$(uptime 2>/dev/null | sed 's/^[[:space:]]*//;s/^/ /')"
fi
NICETIES
    chmod 0644 /etc/profile.d/30-aok-niceties.sh
    
    provision_service_enable_start ssh ssh
    provision_service_enable_start rsyslog
    provision_service_enable_start cron
    provision_service_enable_start chrony
    
    tui_msg "Devuan Provisioning Complete" "Devuan has been provisioned successfully!"
}

# Provisioning mutates the live system, so it wants fail-fast semantics. That
# used to come from a shell-wide `set -eE` in config.sh, which also applied to
# the interactive TUI and turned every dialog Cancel into a fatal error. The
# strictness now lives here, scoped to this routine and contained in a subshell
# so a failure aborts the provisioning run without tearing down the menu.
provision_devuan() {
    run_strict "provision_devuan" provision_devuan_impl "$@"
}

export -f provision_devuan_impl provision_devuan
