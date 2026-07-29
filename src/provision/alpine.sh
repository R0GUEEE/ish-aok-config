#!/bin/bash
###############################################################################
# systui — Provision Alpine Linux 3.23+
###############################################################################

provision_alpine() {
    local tz="$1" user="$2" host="$3" nopass="$4"
    
    log "Starting Alpine Linux provisioning..."
    run_cmd "apk update" apk update || true
    
    local pkgs="bash bash-completion cmake coreutils findutils grep sed gawk diffutils util-linux-misc procps-ng shadow file less openrc openssh openssh-server sudo syslog-ng syslog-ng-openrc chrony cronie cronie-openrc logrotate tzdata ca-certificates openssl man-db man-pages curl wget rsync bind-tools iproute2 git strace build-base gdb linux-headers python3 py3-pip vim neovim nano tmux htop btop ncdu lsof pv tree mc fzf ripgrep fd bat eza jq yq most w3m lynx nmap socat netcat-openbsd mtr tar unzip zip p7zip bzip2 gzip zstd xz fastfetch figlet ncurses lazygit"
    
    run_cmd "Installing packages" apk add --no-progress $pkgs || {
        log "WARN: apk add reported errors; continuing"
    }
    
    [ -f "/usr/share/zoneinfo/$tz" ] && {
        run_cmd "Setting timezone to $tz" sh -c "ln -sf /usr/share/zoneinfo/$tz /etc/localtime && echo '$tz' > /etc/timezone"
    }
    
    if ! grep -q '^LANG=' /etc/environment 2>/dev/null; then
        run_cmd "Setting locale C.UTF-8" sh -c "printf 'LANG=C.UTF-8\nLC_ALL=C.UTF-8\n' >> /etc/environment"
    fi
    
    [ ! -s /etc/machine-id ] && {
        run_cmd "Generating machine-id" sh -c "{ openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n'; } > /etc/machine-id && chmod 0444 /etc/machine-id"
    }
    
    [ -n "$host" ] && run_cmd "Setting hostname to $host" sh -c "echo '$host' > /etc/hostname && hostname '$host' 2>/dev/null || true"
    
    grep -q '^@includedir /etc/sudoers.d' /etc/sudoers 2>/dev/null || \
        run_cmd "Configuring sudoers" sh -c "echo '@includedir /etc/sudoers.d' >> /etc/sudoers"
    
    if [ "$nopass" = 1 ]; then
        run_cmd "Setting passwordless sudo for wheel" sh -c "echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel && chmod 0440 /etc/sudoers.d/wheel"
    else
        run_cmd "Setting sudo with password for wheel" sh -c "echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel && chmod 0440 /etc/sudoers.d/wheel"
    fi
    
    if [ -n "$user" ] && [ "$user" != root ] && ! id "$user" >/dev/null 2>&1; then
        run_cmd "Creating user $user" adduser -D -s /bin/bash "$user" 2>/dev/null || adduser -D "$user" 2>/dev/null
    fi
    
    if [ -n "$user" ] && id "$user" >/dev/null 2>&1; then
        id -nG "$user" | tr ' ' '\n' | grep -qx wheel || run_cmd "Adding $user to wheel" adduser "$user" wheel 2>/dev/null || true
    fi
    
    grep -qx /bin/bash /etc/shells 2>/dev/null || run_cmd "Adding bash to shells" sh -c "echo /bin/bash >> /etc/shells"
    for u in root $user; do
        id "$u" >/dev/null 2>&1 && run_cmd "Setting $u shell to bash" chsh -s /bin/bash "$u" >/dev/null 2>&1 || true
    done
    
    run_cmd "Creating MOTD" cat > /etc/motd <<'MOTD'

   Alpine Linux 3.23  .  iSH-AOK  (terminal-only userspace)
   -------------------------------------------------------
   services :  rc-service <n> {start|stop|status}
   on boot  :  rc-update {add|del} <n> <runlevel>
   status   :  rc-status            logs : /var/log/messages
   time     :  chronyc tracking     docs : man <command>
   -------------------------------------------------------

MOTD
    
    run_cmd "Creating shell niceties" cat > /etc/profile.d/30-aok-niceties.sh <<'NICETIES'
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
alias free='free -m'
alias ..='cd ..'
alias ...='cd ../..'
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
  printf '\n  \033[1;36m%s\033[0m  .  kernel \033[1m%s\033[0m  .  %s\n' \
    "Alpine Linux" "$(uname -r)" "$(uname -m)"
  printf '  uptime:%s\n' "$(uptime 2>/dev/null | sed 's/^[[:space:]]*//;s/^/ /')"
  printf '  disk /: %s   mem: %s\n\n' \
    "$(command df -h / 2>/dev/null | awk 'NR==2{print $3" / "$2" ("$5")"}')" \
    "$(command free -m 2>/dev/null | awk '/^Mem:/{print $3"M / "$2"M"}')"
fi
NICETIES
    chmod 0644 /etc/profile.d/30-aok-niceties.sh
    
    for s in bootmisc hostname syslog-ng seedrng sshd cronie chronyd local; do
        run_cmd "Enabling service $s" rc-update add "$s" $([ "$s" = sshd ] && echo default || echo boot) >/dev/null 2>&1 || true
        rc-service "$s" restart >/dev/null 2>&1 || rc-service "$s" start >/dev/null 2>&1 || true
    done
    
    tui_msg "Alpine Provisioning Complete" "Alpine Linux has been provisioned successfully.\n\nRe-login to activate bash + MOTD.\n\nServices enabled: sshd, syslog-ng, cronie, chronyd"
}

export -f provision_alpine
