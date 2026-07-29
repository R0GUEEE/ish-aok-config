#!/bin/sh
# Targeted performance optimizations for iSH-AOK.
#
# iSH-AOK emulates x86 on iOS, so process startup, forks and small-file
# filesystem operations are far more expensive than on native Linux, while
# most kernel tunables are read-only. Every wizard here therefore works in
# user space, writes reversible marked blocks, and confirms before deleting.

perfopt_target_profile(){ printf '%s' "$CURRENT_HOME/.profile"; }

# Remove a marked block entirely, rather than replacing it with empty markers.
perfopt_strip_block(){
  _f=$1; _name=$2
  [ -f "$_f" ] || return 0
  _b="# >>> ish-aok-config: $_name >>>"; _e="# <<< ish-aok-config: $_name <<<"
  _t=$TMP_DIR/perfopt-strip
  awk -v b="$_b" -v e="$_e" '$0==b{s=1;next} $0==e{s=0;next} !s{print}' "$_f" >"$_t" || return 1
  write_file "$_f" 644 "$(cat "$_t")"
}

perfopt_runtime_tuning(){
  cpu=$(performance_cpu_count); mem=$(performance_mem_kb)
  memmb=$((mem / 1024)); [ "$memmb" -gt 0 ] || memmb=512
  heap=$((memmb / 4)); [ "$heap" -lt 96 ] && heap=96
  sel=$(ui_checklist 'Language runtime tuning' \
    "Interpreters start slowly under emulation. Detected: ${cpu} CPU, ${memmb} MiB RAM." \
    python 'Python: shared bytecode cache, quiet pip' on \
    node "Node: cap heap at ${heap} MiB, disable update checks" on \
    ruby 'Ruby: skip documentation generation' off \
    go "Go: match build parallelism to ${cpu} CPU" off) || return 0
  [ -n "$sel" ] || { ui_msg 'Runtime tuning' 'Nothing selected; no changes were made.'; return 0; }
  body='# Language runtime tuning for iSH-AOK'
  for r in $sel; do
    case $r in
      python) body="$body\nexport PYTHONPYCACHEPREFIX=\"\$HOME/.cache/pycache\"\nexport PIP_DISABLE_PIP_VERSION_CHECK=1\nexport PIP_NO_INPUT=1";;
      node) body="$body\nexport NODE_OPTIONS=\"--max-old-space-size=$heap\"\nexport NO_UPDATE_NOTIFIER=1\nexport NPM_CONFIG_FUND=false\nexport NPM_CONFIG_AUDIT=false";;
      ruby) body="$body\nexport GEM_OPTS=\"--no-document\"\nexport BUNDLE_JOBS=1";;
      go) body="$body\nexport GOMAXPROCS=$cpu\nexport GOFLAGS=\"-p=$cpu\"";;
    esac
  done
  replace_block "$(perfopt_target_profile)" runtime "$body"
  ui_msg 'Runtime tuning' 'Applied. Open a new shell to load the settings.'
}

perfopt_memory_tuning(){
  mem=$(performance_mem_kb); memmb=$((mem / 1024)); [ "$memmb" -gt 0 ] || memmb=512
  sel=$(ui_checklist 'Memory tuning' \
    "iOS reclaims memory aggressively. Detected: ${memmb} MiB RAM." \
    arenas 'Limit malloc arenas (lower resident memory)' on \
    trim 'Return freed heap pages to the system sooner' on \
    coredump 'Disable core dumps for new shells' on \
    oomhint 'Prefer background jobs to be killed first' off) || return 0
  [ -n "$sel" ] || { ui_msg 'Memory tuning' 'Nothing selected; no changes were made.'; return 0; }
  body='# Memory tuning for iSH-AOK'
  for r in $sel; do
    case $r in
      arenas) body="$body\nexport MALLOC_ARENA_MAX=2";;
      trim) body="$body\nexport MALLOC_TRIM_THRESHOLD_=131072\nexport MALLOC_MMAP_THRESHOLD_=131072";;
      coredump) body="$body\nulimit -c 0 2>/dev/null || true";;
      oomhint) body="$body\n[ -w /proc/self/oom_score_adj ] && echo 200 >/proc/self/oom_score_adj 2>/dev/null || true";;
    esac
  done
  replace_block "$(perfopt_target_profile)" memory "$body"
  ui_msg 'Memory tuning' 'Applied. Open a new shell to load the settings.'
}

perfopt_fs_write_tuning(){
  sel=$(ui_checklist 'Filesystem write reduction' \
    'Small writes are expensive on the iOS-backed filesystem. These settings reduce them.' \
    history 'Trim shell and pager history files' on \
    tmp 'Keep temporary files in one cache directory' on \
    git 'Reduce Git background work and lock churn' on \
    editors 'Stop editors writing swap and backup files' off) || return 0
  [ -n "$sel" ] || { ui_msg 'Filesystem tuning' 'Nothing selected; no changes were made.'; return 0; }
  body='# Filesystem write reduction for iSH-AOK'
  for r in $sel; do
    case $r in
      history) body="$body\nexport HISTSIZE=1000\nexport HISTFILESIZE=1000\nexport LESSHISTFILE=-\nexport HISTCONTROL=ignoreboth";;
      tmp) body="$body\nexport TMPDIR=\"\$HOME/.cache/tmp\"\n[ -d \"\$TMPDIR\" ] || mkdir -p \"\$TMPDIR\" 2>/dev/null || true";;
      git) body="$body\nexport GIT_OPTIONAL_LOCKS=0";;
      editors) body="$body\nexport VIMINIT=\"set nobackup noswapfile noundofile\"";;
    esac
  done
  replace_block "$(perfopt_target_profile)" fswrites "$body"
  case " $sel " in
    *' git '*)
      if have git; then
        git config --global gc.auto 0 2>/dev/null || true
        git config --global core.untrackedCache true 2>/dev/null || true
        git config --global core.fsmonitor false 2>/dev/null || true
      fi
      ;;
  esac
  ui_msg 'Filesystem tuning' 'Applied. Open a new shell to load the settings.'
}

perfopt_slim_paths(){
  printf '%s\n' /usr/share/man /usr/share/doc /usr/share/info /usr/share/locale
}

perfopt_slim_system(){
  before=$(df -k / 2>/dev/null | awk 'NR==2{print $4}')
  sizes=''
  for p in $(perfopt_slim_paths); do
    [ -d "$p" ] || continue
    sizes="$sizes$(du -sh "$p" 2>/dev/null || printf '? %s' "$p")\n"
  done
  [ -n "$sizes" ] || { ui_msg 'Reclaim space' 'No documentation or locale directories were found.'; return 0; }
  sel=$(ui_checklist 'Reclaim space' \
    "Documentation and locale data cost space and slow filesystem scans.\n\nCurrent usage:\n$(printf '%b' "$sizes")" \
    man 'Manual pages (/usr/share/man)' off \
    doc 'Package documentation (/usr/share/doc, /usr/share/info)' off \
    locale 'Extra locales (/usr/share/locale)' off \
    caches 'Package manager and user caches' on) || return 0
  [ -n "$sel" ] || { ui_msg 'Reclaim space' 'Nothing selected; no changes were made.'; return 0; }
  ui_yesno 'Reclaim space' 'Selected files will be deleted. Reinstalling the related packages restores them. Continue?' || return 0
  for r in $sel; do
    case $r in
      man) as_root rm -rf /usr/share/man/* 2>/dev/null || true;;
      doc) as_root rm -rf /usr/share/doc/* /usr/share/info/* 2>/dev/null || true;;
      locale) as_root rm -rf /usr/share/locale/* 2>/dev/null || true;;
      caches) package_clean; rm -rf "$CURRENT_HOME/.cache"/* 2>/dev/null || true;;
    esac
  done
  after=$(df -k / 2>/dev/null | awk 'NR==2{print $4}')
  if [ -n "$before" ] && [ -n "$after" ] && [ "$after" -ge "$before" ] 2>/dev/null; then
    freed=$(( (after - before) / 1024 ))
    ui_msg 'Reclaim space' "Completed. Approximately ${freed} MiB reclaimed."
  else
    ui_msg 'Reclaim space' 'Completed.'
  fi
}

perfopt_pkg_speed(){
  case ${PKG_MGR:-} in
    apt)
      sel=$(ui_checklist 'Package manager speed' \
        'APT downloads translations and documentation that are rarely useful on iSH-AOK.' \
        languages 'Skip translation downloads' on \
        docs 'Skip man pages and docs on future installs' on \
        recommends 'Skip recommended (optional) packages' off) || return 0
      [ -n "$sel" ] || { ui_msg 'Package manager' 'Nothing selected; no changes were made.'; return 0; }
      conf=''
      for r in $sel; do
        case $r in
          languages) conf="${conf}Acquire::Languages \"none\";\n";;
          recommends) conf="${conf}APT::Install-Recommends \"false\";\nAPT::Install-Suggests \"false\";\n";;
        esac
      done
      [ -n "$conf" ] && as_root sh -c "printf '%b' '$conf' >/etc/apt/apt.conf.d/99-ish-aok-performance"
      case " $sel " in
        *' docs '*)
          as_root sh -c "printf '%s\n' 'path-exclude /usr/share/man/*' 'path-exclude /usr/share/doc/*' 'path-exclude /usr/share/info/*' >/etc/dpkg/dpkg.cfg.d/99-ish-aok-performance"
          ;;
      esac
      ui_msg 'Package manager' 'APT configured. Settings apply to future installs.'
      ;;
    apk)
      sel=$(ui_checklist 'Package manager speed' \
        'APK is already lean. These options reduce cache writes and download size.' \
        nocache 'Do not keep a local package cache' on \
        purge 'Clear the existing cache now' on) || return 0
      [ -n "$sel" ] || { ui_msg 'Package manager' 'Nothing selected; no changes were made.'; return 0; }
      case " $sel " in
        *' nocache '*) as_root rm -f /etc/apk/cache 2>/dev/null || true;;
      esac
      case " $sel " in
        *' purge '*) run_capture 'Clearing package cache' as_root apk cache clean;;
      esac
      ui_msg 'Package manager' 'APK cache settings applied.'
      ;;
    *)
      ui_msg 'Package manager' "No speed options are available for ${PKG_MGR:-the detected package manager}. Use Clean caches instead."
      ;;
  esac
}

perfopt_startup_tuning(){
  sel=$(ui_checklist 'Shell startup speed' \
    'Every new shell pays emulation cost for the work done at startup.' \
    prompt 'Use a lightweight prompt instead of a framework prompt' on \
    cnf 'Disable the slow command-not-found handler' on \
    completion 'Skip loading large completion sets automatically' off \
    motd 'Skip the message of the day' off) || return 0
  [ -n "$sel" ] || { ui_msg 'Shell startup' 'Nothing selected; no changes were made.'; return 0; }
  body='# Shell startup tuning for iSH-AOK'
  for r in $sel; do
    case $r in
      prompt) body="$body\nPS1='\\\\u@\\\\h:\\\\w\\\\\$ '\nexport STARSHIP_DISABLE=1";;
      cnf) body="$body\nunset -f command_not_found_handle 2>/dev/null || true\nunset -f command_not_found_handler 2>/dev/null || true";;
      completion) body="$body\nexport BASH_COMPLETION_USER_FILE=/dev/null";;
      motd) body="$body\nexport ISH_AOK_SKIP_MOTD=1";;
    esac
  done
  replace_block "$(perfopt_target_profile)" startup "$body"
  ui_msg 'Shell startup' 'Applied. Open a new shell to measure the difference with the startup audit.'
}

perfopt_recommended(){
  cpu=$(performance_cpu_count); mem=$(performance_mem_kb); memmb=$((mem / 1024))
  [ "$memmb" -gt 0 ] || memmb=512
  heap=$((memmb / 4)); [ "$heap" -lt 96 ] && heap=96
  jobs=$cpu; [ "$jobs" -gt 2 ] && jobs=2
  ui_yesno 'Recommended optimizations' \
    "Apply the reversible iSH-AOK optimization set?\n\nBuild jobs: $jobs\nNode heap: ${heap} MiB\nMalloc arenas: 2\nHistory: 1000 entries\nCore dumps: disabled\nGit background work: reduced\n\nNothing is deleted and every change lives in a marked .profile block." || return 0
  replace_block "$(perfopt_target_profile)" recommended "# Recommended iSH-AOK optimization set\nexport MAKEFLAGS=\"-j$jobs\"\nexport CMAKE_BUILD_PARALLEL_LEVEL=$jobs\nexport CARGO_BUILD_JOBS=$jobs\nexport MALLOC_ARENA_MAX=2\nexport MALLOC_TRIM_THRESHOLD_=131072\nexport NODE_OPTIONS=\"--max-old-space-size=$heap\"\nexport NO_UPDATE_NOTIFIER=1\nexport PIP_DISABLE_PIP_VERSION_CHECK=1\nexport PYTHONPYCACHEPREFIX=\"\$HOME/.cache/pycache\"\nexport HISTSIZE=1000\nexport HISTFILESIZE=1000\nexport LESSHISTFILE=-\nexport GIT_OPTIONAL_LOCKS=0\nexport TMPDIR=\"\$HOME/.cache/tmp\"\n[ -d \"\$TMPDIR\" ] || mkdir -p \"\$TMPDIR\" 2>/dev/null || true\nulimit -c 0 2>/dev/null || true"
  if have git; then
    git config --global gc.auto 0 2>/dev/null || true
    git config --global core.untrackedCache true 2>/dev/null || true
  fi
  ui_msg 'Recommended optimizations' 'Applied to .profile. Open a new shell to load the settings.'
}

perfopt_revert(){
  f=$(perfopt_target_profile)
  [ -f "$f" ] || { ui_msg 'Revert' 'No .profile was found.'; return 0; }
  applied=$(grep -o '# >>> ish-aok-config: [a-z]* >>>' "$f" 2>/dev/null | awk '{print $4}' | sort -u)
  [ -n "$applied" ] || { ui_msg 'Revert' 'No optimization blocks are present in .profile.'; return 0; }
  set --
  for b in $applied; do
    case $b in
      runtime|memory|fswrites|startup|recommended|performance|shellperf|build) set -- "$@" "$b" "Remove the $b block" off;;
    esac
  done
  [ "$#" -gt 0 ] || { ui_msg 'Revert' 'No optimization blocks are present in .profile.'; return 0; }
  sel=$(ui_checklist 'Revert optimizations' 'Select the marked blocks to remove from .profile.' "$@") || return 0
  [ -n "$sel" ] || return 0
  for b in $sel; do perfopt_strip_block "$f" "$b"; done
  ui_msg 'Revert' 'Selected blocks were removed. Open a new shell to load the previous settings.'
}

performance_optimize_menu(){
  while :; do
    c=$(ui_menu 'Optimization' 'Reversible, user-space optimizations tuned for iSH-AOK emulation.' \
      recommended 'Apply the recommended optimization set' \
      runtime 'Language runtimes (Python, Node, Ruby, Go)' \
      memory 'Memory allocator and core-dump limits' \
      fsio 'Reduce filesystem writes' \
      startup 'Shell startup and prompt speed' \
      pkgspeed 'Package manager download and cache options' \
      slim 'Reclaim space from docs, locales and caches' \
      revert 'Review and revert applied optimizations' \
      back 'Back') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }
    case $c in
      recommended) perfopt_recommended;;
      runtime) perfopt_runtime_tuning;;
      memory) perfopt_memory_tuning;;
      fsio) perfopt_fs_write_tuning;;
      startup) perfopt_startup_tuning;;
      pkgspeed) perfopt_pkg_speed;;
      slim) perfopt_slim_system;;
      revert) perfopt_revert;;
      back) return 0;;
    esac
  done
}
