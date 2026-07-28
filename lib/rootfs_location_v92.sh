#!/bin/sh
# v9.2 RootFS destination selection and validation.
V92_LOCATION_STATE=${V92_LOCATION_STATE:-$STATE_DIR/rootfs-locations-v92}
V92_RECENT_LOCATIONS=${V92_RECENT_LOCATIONS:-$V92_LOCATION_STATE/recent.tsv}
mkdir -p "$V92_LOCATION_STATE" 2>/dev/null || true

rootfs_location_normalize(){
  p=$1
  [ -n "$p" ] || return 1
  case $p in /*) :;; *) return 1;; esac
  while [ "$p" != / ] && [ "${p%/}" != "$p" ]; do p=${p%/}; done
  printf '%s\n' "$p"
}

rootfs_location_safe(){
  p=$(rootfs_location_normalize "$1") || return 1
  case $p in /|/AOK|/opt/AOK|/root|/home|/usr|/var|/etc|/bin|/sbin|/lib|/lib64) return 1;; esac
  case $p in *'/../'*|*/..|*'/./'*|*/.) return 1;; esac
  return 0
}

rootfs_location_parent_writable(){
  p=$(rootfs_location_normalize "$1") || return 1
  d=$(dirname "$p")
  while [ ! -e "$d" ] && [ "$d" != / ]; do d=$(dirname "$d"); done
  [ -d "$d" ] && { [ -w "$d" ] || is_root || have sudo || have doas; }
}

rootfs_location_validate(){
  p=$(rootfs_location_normalize "$1") || { printf 'Destination must be an absolute path.\n'; return 1; }
  rootfs_location_safe "$p" || { printf 'Unsafe RootFS destination: %s\n' "$p"; return 1; }
  rootfs_location_parent_writable "$p" || { printf 'Destination parent is not writable: %s\n' "$(dirname "$p")"; return 1; }
  return 0
}

rootfs_location_remember(){
  p=$(rootfs_location_normalize "$1") || return 1
  rootfs_location_safe "$p" || return 1
  mkdir -p "$V92_LOCATION_STATE"
  t="$V92_RECENT_LOCATIONS.tmp.$$"
  { printf '%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date)" "$p"; awk -F '\t' -v p="$p" '$2!=p{print}' "$V92_RECENT_LOCATIONS" 2>/dev/null | head -n 19; } >"$t" && mv "$t" "$V92_RECENT_LOCATIONS"
}

rootfs_location_recent_paths(){ awk -F '\t' 'NF>1{print $2}' "$V92_RECENT_LOCATIONS" 2>/dev/null; }

rootfs_location_default(){
  name=${1:-rootfs}; release=${2:-}; arch=${3:-arm64}
  n=$(printf '%s' "$name" | tr ' /' '--' | tr -cd 'A-Za-z0-9._-')
  [ -n "$release" ] && n="$n-$release"
  [ -n "$arch" ] && n="$n-$arch"
  printf '/AOK/roots/%s\n' "$n"
}

rootfs_location_registered_parents(){
  { rootfs_registry_paths 2>/dev/null || true; } | while IFS= read -r p; do [ -n "$p" ] && dirname "$p"; done | awk '!seen[$0]++'
}

rootfs_location_choose_recent(){
  set --
  while IFS= read -r p; do [ -n "$p" ] && set -- "$@" "$p" "$p"; done <<EOF_RECENT
$(rootfs_location_recent_paths)
EOF_RECENT
  [ "$#" -gt 0 ] || { ui_msg 'RootFS location' 'No recent destinations are recorded.'; return 1; }
  ui_menu 'Recent RootFS locations' 'Select a previously used destination.' "$@"
}

rootfs_location_choose_registered_parent(){
  set --
  while IFS= read -r p; do [ -n "$p" ] && set -- "$@" "$p" "$p"; done <<EOF_PARENTS
$(rootfs_location_registered_parents)
EOF_PARENTS
  [ "$#" -gt 0 ] || { ui_msg 'RootFS location' 'No registered RootFS parent directories were found.'; return 1; }
  ui_menu 'Registered RootFS locations' 'Select a parent directory.' "$@"
}

rootfs_location_select(){
  suggested=${1:-/AOK/roots/rootfs}
  label=${2:-rootfs}
  while :; do
    c=$(ui_menu 'Select RootFS location' "Suggested destination: $suggested" \
      suggested 'Use suggested destination' \
      aok '/AOK/roots' \
      root '/root' \
      opt '/opt/AOK/roots' \
      registered 'Parent of a registered RootFS' \
      recent 'Recent destination' \
      custom 'Enter a custom absolute path') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return 1; };
    case $c in
      suggested) p=$suggested;;
      aok) p="/AOK/roots/$label";;
      root) p="/root/$label";;
      opt) p="/opt/AOK/roots/$label";;
      registered) base=$(rootfs_location_choose_registered_parent) || continue; p="$base/$label";;
      recent) p=$(rootfs_location_choose_recent) || continue;;
      custom) p=$(ui_input 'RootFS location' 'Absolute destination path' "$suggested") || continue;;
    esac
    p=$(rootfs_location_normalize "$p") || { ui_msg 'RootFS location' 'Enter an absolute path.'; continue; }
    msg=$(rootfs_location_validate "$p" 2>&1) || { ui_msg 'RootFS location' "$msg"; continue; }
    if [ -d "$p" ] && [ -n "$(find "$p" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
      ui_yesno 'RootFS location' "Destination is not empty:\n$p\n\nUse it anyway? Existing files may be modified." || continue
    elif [ -e "$p" ] && [ ! -d "$p" ]; then
      ui_msg 'RootFS location' "Destination exists and is not a directory:\n$p"; continue
    fi
    rootfs_location_remember "$p"
    printf '%s\n' "$p"
    return 0
  done
}

rootfs_location_report(){
  printf 'iSH-AOK Config 9.2.0 — RootFS Locations\n\n'
  printf 'Standard locations:\n  /AOK/roots\n  /opt/AOK/roots\n  /root\n\n'
  printf 'Recent locations:\n'
  rootfs_location_recent_paths | sed 's/^/  /'
}
