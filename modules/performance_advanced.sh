#!/bin/sh

performance_cpu_count(){ getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 1; }
performance_mem_kb(){ awk '/MemTotal:/{print $2;exit}' /proc/meminfo 2>/dev/null || echo 0; }
performance_profile_block(){
    name=$1 jobs=$2 hist=$3 niceval=$4
    replace_block "$CURRENT_HOME/.profile" "performance-$name" "# Generated performance profile: $name
export MAKEFLAGS=\"-j$jobs\"
export CMAKE_BUILD_PARALLEL_LEVEL=$jobs
export CARGO_BUILD_JOBS=$jobs
export NINJAFLAGS=\"-j$jobs\"
export HISTSIZE=$hist
export HISTFILESIZE=$hist
export LESSHISTFILE=-
export GIT_OPTIONAL_LOCKS=0
export ISH_AOK_DEFAULT_NICE=$niceval"
}
performance_apply_advanced_profile(){
    cpu=$(performance_cpu_count); mem=$(performance_mem_kb)
    p=$(ui_radiolist 'Performance profile' "CPU threads: $cpu | Memory: $((mem/1024)) MiB" \
        ultra_low 'Ultra-low memory; one build job' off \
        low 'Low memory; conservative caches' on \
        balanced 'Balanced interactive use' off \
        build 'Compilation and developer workload' off \
        server 'SSH/server background workload' off \
        custom 'Choose job and history limits' off) || return
    case $p in
        ultra_low) jobs=1; hist=200; niceval=10;;
        low) jobs=1; hist=750; niceval=5;;
        balanced) jobs=$cpu; [ "$jobs" -gt 2 ] && jobs=2; hist=2500; niceval=0;;
        build) jobs=$cpu; hist=5000; niceval=0;;
        server) jobs=1; hist=1000; niceval=5;;
        custom) jobs=$(ui_input Performance 'Parallel build jobs:' 1) || return; hist=$(ui_input Performance 'Shell history entries:' 1000) || return; niceval=$(ui_input Performance 'Default nice value (0-19):' 0) || return;;
    esac
    performance_profile_block "$p" "$jobs" "$hist" "$niceval"
    ui_msg Performance "Applied $p profile. New shells will inherit the settings."
}
performance_limits_wizard(){
    need_root || return
    user=$(ui_input Limits 'User name or * for all users:' "$CURRENT_USER") || return
    nofile=$(ui_input Limits 'Open-file soft limit:' 4096) || return
    nofile_hard=$(ui_input Limits 'Open-file hard limit:' 8192) || return
    nproc=$(ui_input Limits 'Process soft limit:' 1024) || return
    core=$(ui_radiolist Limits 'Core dump policy' zero 'Disable core dumps' on unlimited 'Allow unlimited core dumps' off) || return
    [ "$core" = zero ] && coreval=0 || coreval=unlimited
    f=/etc/security/limits.d/90-ish-aok-performance.conf
    write_file "$f" 644 "$user soft nofile $nofile
$user hard nofile $nofile_hard
$user soft nproc $nproc
$user hard core $coreval"
    ui_msg Limits "Wrote $f. PAM-based limits may not apply inside every iSH-AOK rootfs."
}
performance_process_priority_wizard(){
    have ps || { ui_msg Priority 'ps is required.'; return; }
    out=$REPORT_DIR/process-priority-$(date +%Y%m%d-%H%M%S).txt
    ps -eo pid,ppid,ni,stat,rss,etime,comm,args 2>/dev/null | sort -k5 -nr >"$out"
    action=$(ui_menu 'Process priority' 'Inspect or adjust a running process.' list 'View processes sorted by memory' renice 'Change process nice value' stop 'Send STOP signal' continue 'Send CONT signal' terminate 'Send TERM signal') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $action in
        list) ui_text 'Processes' "$(head -n 250 "$out")";;
        *) pid=$(ui_input Process 'PID:' '') || return; case $action in renice) val=$(ui_input Renice 'Nice value (-20 to 19):' 5) || return; run_capture 'Changing process priority' renice "$val" -p "$pid";; stop) run_capture 'Pausing process' kill -STOP "$pid";; continue) run_capture 'Continuing process' kill -CONT "$pid";; terminate) ui_yesno Process "Terminate PID $pid?" && run_capture 'Terminating process' kill -TERM "$pid";; esac;;
    esac
}
performance_cache_wizard(){
    choices=$(ui_checklist 'Cache cleanup' 'Select caches to clean. Configuration and user documents are preserved.' \
        packages 'Package-manager caches' on \
        usercache 'User ~/.cache contents' off \
        thumbnails 'Thumbnail caches' off \
        pip 'pip cache' off \
        npm 'npm cache' off \
        cargo 'Cargo registry Git/checkouts cache' off \
        go 'Go build cache' off \
        logs 'Rotated/compressed logs' off \
        temp 'Temporary files older than one day' on) || return
    for x in $choices; do case $x in
        packages) package_clean;;
        usercache) ui_yesno Cache 'Delete all files under ~/.cache?' && rm -rf "$CURRENT_HOME/.cache"/* "$CURRENT_HOME/.cache"/.[!.]* 2>/dev/null || true;;
        thumbnails) rm -rf "$CURRENT_HOME/.cache/thumbnails" 2>/dev/null || true;;
        pip) have pip && progress_run 'Cleaning pip cache' pip cache purge || have pip3 && progress_run 'Cleaning pip cache' pip3 cache purge || true;;
        npm) have npm && progress_run 'Cleaning npm cache' npm cache clean --force || true;;
        cargo) rm -rf "$CURRENT_HOME/.cargo/registry/cache" "$CURRENT_HOME/.cargo/git/checkouts" 2>/dev/null || true;;
        go) have go && progress_run 'Cleaning Go build cache' go clean -cache -testcache || true;;
        logs) need_root && as_root find /var/log -type f \( -name '*.gz' -o -name '*.old' -o -name '*.[0-9]' \) -delete 2>/dev/null || true;;
        temp) find "${TMPDIR:-/tmp}" -mindepth 1 -mtime +1 -user "$(id -u)" -exec rm -rf {} + 2>/dev/null || true;;
    esac; done
    ui_msg Cache 'Selected cleanup actions completed.'
}
performance_shell_startup_audit(){
    shellcmd=${SHELL:-/bin/sh}; out=$REPORT_DIR/shell-startup-$(date +%Y%m%d-%H%M%S).txt
    { echo "Shell: $shellcmd"; echo; i=1; while [ $i -le 5 ]; do if have time; then { time "$shellcmd" -i -c exit; } 2>&1; else "$shellcmd" -i -c exit; fi; i=$((i+1)); done; echo; echo 'Startup files:'; for f in "$CURRENT_HOME/.profile" "$CURRENT_HOME/.bashrc" "$CURRENT_HOME/.bash_profile" "$CURRENT_HOME/.zshrc" "$CURRENT_HOME/.config/fish/config.fish"; do [ -f "$f" ] && wc -l -c "$f"; done; } >"$out"
    ui_text 'Shell startup audit' "$(cat "$out")"
}
performance_service_audit(){
    out=$REPORT_DIR/service-performance-$(date +%Y%m%d-%H%M%S).txt
    { echo 'Init system:' "$INIT_SYSTEM"; echo; echo '[running processes by RSS]'; ps -eo pid,rss,etime,comm,args 2>/dev/null | sort -k2 -nr | head -n 80; echo; echo '[SysV services]'; for f in /etc/rc?.d/S*; do [ -e "$f" ] && echo "$f -> $(readlink "$f" 2>/dev/null)"; done; echo; echo '[OpenRC enabled]'; have rc-status && rc-status -a 2>/dev/null || true; } >"$out"
    ui_text 'Service performance audit' "$(cat "$out")"
}
performance_storage_audit(){
    out=$REPORT_DIR/storage-performance-$(date +%Y%m%d-%H%M%S).txt
    { df -h 2>/dev/null; echo; df -i 2>/dev/null; echo; echo '[largest top-level paths]'; du -x -k /var /usr "$CURRENT_HOME" 2>/dev/null | sort -n | tail -n 80; echo; echo '[mounts]'; cat /proc/mounts 2>/dev/null; } >"$out"
    ui_text 'Storage performance audit' "$(cat "$out")"
}
performance_low_memory_guard(){
    target=$CURRENT_HOME/.local/bin/ish-aok-lowmem-run; mkdir -p "$(dirname "$target")"
    cat >"$target" <<'EOS'
#!/bin/sh
# Run a command with conservative priority and build parallelism.
export MAKEFLAGS=-j1 CMAKE_BUILD_PARALLEL_LEVEL=1 CARGO_BUILD_JOBS=1 NINJAFLAGS=-j1
if command -v nice >/dev/null 2>&1; then exec nice -n "${ISH_AOK_NICE:-10}" "$@"; fi
exec "$@"
EOS
    chmod 755 "$target"; ui_msg 'Low-memory runner' "Installed $target\nExample: ish-aok-lowmem-run cargo build --release"
}
performance_benchmark_suite(){
    out=$REPORT_DIR/performance-benchmark-$(date +%Y%m%d-%H%M%S).txt
    progress_run 'Running lightweight performance suite' sh -c '
        out=$1
        {
          echo "date=$(date)"; uname -a; echo
          echo "[shell arithmetic]"; time sh -c "i=0; while [ \$i -lt 100000 ]; do i=\$((i+1)); done"
          echo "[filesystem write]"; f=${TMPDIR:-/tmp}/ish-aok-bench.$$; time dd if=/dev/zero of=$f bs=1024 count=8192 conv=fsync 2>&1; rm -f $f
          echo "[compression]"; command -v gzip >/dev/null && time sh -c "dd if=/dev/zero bs=1024 count=4096 2>/dev/null | gzip -1 >/dev/null"
          echo "[memory]"; cat /proc/meminfo 2>/dev/null | head -n 12
        } >"$out" 2>&1
    ' sh "$out"
    ui_text Benchmark "$(cat "$out")"
}
performance_advanced_menu(){
    while :; do
        c=$(ui_menu 'Advanced performance tuning' 'Reversible, user-space-first tuning suitable for iSH-AOK.' \
            profiles 'Apply low-memory, balanced, build or server profile' \
            limits 'Configure open-file/process/core limits' \
            priority 'Inspect and adjust running-process priority' \
            cache 'Selectable cache and temporary-file cleanup' \
            shellaudit 'Measure shell startup and configuration size' \
            services 'Audit enabled services and memory-heavy processes' \
            storage 'Storage, inode, mount and large-path audit' \
            lowmem 'Install low-memory command wrapper' \
            benchmark 'Run lightweight CPU/filesystem/compression benchmark' \
            report 'Generate complete performance report') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
        case $c in profiles) performance_apply_advanced_profile;; limits) performance_limits_wizard;; priority) performance_process_priority_wizard;; cache) performance_cache_wizard;; shellaudit) performance_shell_startup_audit;; services) performance_service_audit;; storage) performance_storage_audit;; lowmem) performance_low_memory_guard;; benchmark) performance_benchmark_suite;; report) performance_full_report;; esac
    done
}
performance_full_report(){
    out=$REPORT_DIR/performance-full-$(date +%Y%m%d-%H%M%S).txt
    { echo "iSH-AOK Config performance report"; date; echo; uname -a; echo; echo '[CPU]'; grep -E 'processor|model name|Hardware|BogoMIPS' /proc/cpuinfo 2>/dev/null | head -n 40; echo; echo '[memory]'; cat /proc/meminfo 2>/dev/null; echo; echo '[load]'; uptime 2>/dev/null; cat /proc/loadavg 2>/dev/null; echo; echo '[limits]'; cat /proc/self/limits 2>/dev/null; echo; echo '[filesystems]'; df -h 2>/dev/null; echo; echo '[top RSS]'; ps -eo pid,ppid,ni,rss,etime,comm,args 2>/dev/null | sort -k4 -nr | head -n 100; echo; echo '[capabilities]'; for k in kernel.pid_max vm.swappiness vm.overcommit_memory fs.file-max; do p=/proc/sys/$(echo "$k" | tr . /); printf '%s=' "$k"; cat "$p" 2>/dev/null || echo unavailable; done; } >"$out"
    ui_text 'Performance report' "$(cat "$out")"
}
