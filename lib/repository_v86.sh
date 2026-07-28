#!/bin/sh

V86_REPO_STATE=${V86_REPO_STATE:-$STATE_DIR/repository-v86}
V86_REPO_REPORTS=${V86_REPO_REPORTS:-$REPORT_DIR/repository-v86}
mkdir -p "$V86_REPO_STATE" "$V86_REPO_REPORTS" 2>/dev/null || true

repo_v86_root(){ r=${1:-/}; [ -d "$r" ] || return 1; printf '%s\n' "$r"; }
repo_v86_join(){ r=$1; p=$2; [ "$r" = / ] && printf '%s\n' "$p" || printf '%s%s\n' "$r" "$p"; }
repo_v86_manager(){ v84_detect_package_manager "${1:-/}" 2>/dev/null || pkg_detect_manager "${1:-/}" 2>/dev/null || echo unknown; }
repo_v86_safe_file(){ case ${1:-} in /*) case $1 in *../*|*/..|*'\n'*) return 1;; esac;; *) return 1;; esac; }
repo_v86_checksum(){ if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else cksum "$1" | awk '{print $1":"$2}'; fi; }

repo_v86_files(){
  r=$(repo_v86_root "${1:-/}") || return 1; pm=$(repo_v86_manager "$r")
  case $pm in
    apt) [ -f "$(repo_v86_join "$r" /etc/apt/sources.list)" ] && printf '%s\n' /etc/apt/sources.list; d=$(repo_v86_join "$r" /etc/apt/sources.list.d); [ -d "$d" ] && find "$d" -type f \( -name '*.list' -o -name '*.sources' \) 2>/dev/null | awk -v r="$r" '{ if (r != "/") sub("^" r, ""); print }';;
    apk) [ -f "$(repo_v86_join "$r" /etc/apk/repositories)" ] && printf '%s\n' /etc/apk/repositories;;
    pacman) [ -f "$(repo_v86_join "$r" /etc/pacman.conf)" ] && printf '%s\n' /etc/pacman.conf; [ -f "$(repo_v86_join "$r" /etc/pacman.d/mirrorlist)" ] && printf '%s\n' /etc/pacman.d/mirrorlist;;
    dnf|yum) d=$(repo_v86_join "$r" /etc/yum.repos.d); [ -d "$d" ] && find "$d" -type f -name '*.repo' 2>/dev/null | awk -v r="$r" '{ if (r != "/") sub("^" r, ""); print }';;
    xbps) d=$(repo_v86_join "$r" /etc/xbps.d); [ -d "$d" ] && find "$d" -type f -name '*.conf' 2>/dev/null | awk -v r="$r" '{ if (r != "/") sub("^" r, ""); print }';;
    emerge) [ -f "$(repo_v86_join "$r" /etc/portage/make.conf)" ] && printf '%s\n' /etc/portage/make.conf; d=$(repo_v86_join "$r" /etc/portage/repos.conf); [ -d "$d" ] && find "$d" -type f -name '*.conf' 2>/dev/null | awk -v r="$r" '{ if (r != "/") sub("^" r, ""); print }';;
    zypper) d=$(repo_v86_join "$r" /etc/zypp/repos.d); [ -d "$d" ] && find "$d" -type f -name '*.repo' 2>/dev/null | awk -v r="$r" '{ if (r != "/") sub("^" r, ""); print }';;
  esac
}

repo_v86_audit_file(){
  r=$1; rel=$2; full=$(repo_v86_join "$r" "$rel"); [ -f "$full" ] || return 0
  awk -v f="$rel" '
    /^[[:space:]]*($|#)/ {next}
    /http:\/\// {print "WARN\t" f "\tunencrypted transport (http)\t" $0}
    /trusted[[:space:]]*=[[:space:]]*yes|trusted=yes/ {print "FAIL\t" f "\ttrusted=yes bypass\t" $0}
    /gpgcheck[[:space:]]*=[[:space:]]*0/ {print "FAIL\t" f "\tgpgcheck disabled\t" $0}
    /repo_gpgcheck[[:space:]]*=[[:space:]]*0/ {print "WARN\t" f "\trepository metadata signature disabled\t" $0}
    /sslverify[[:space:]]*=[[:space:]]*0/ {print "FAIL\t" f "\tTLS verification disabled\t" $0}
  ' "$full"
}

repo_v86_audit(){
  r=$(repo_v86_root "${1:-/}") || return 1; pm=$(repo_v86_manager "$r"); found=0
  printf 'RootFS: %s\nPackage manager: %s\n\n' "$r" "$pm"
  printf '[repository files]\n'
  files=$(repo_v86_files "$r")
  if [ -n "$files" ]; then printf '%s\n' "$files"; else printf 'none detected\n'; fi
  printf '\n[policy findings]\n'
  for rel in $files; do finding=$(repo_v86_audit_file "$r" "$rel"); [ -n "$finding" ] && { printf '%s\n' "$finding"; found=1; }; done
  [ "$found" -eq 1 ] || printf 'PASS\tNo explicit insecure repository policy was detected.\n'
  printf '\n[package policy]\n'
  repo_v86_policy_report "$r"
}

repo_v86_policy_report(){
  r=${1:-/}; pm=$(repo_v86_manager "$r")
  case $pm in
    apt)
      h=$(repo_v86_join "$r" /var/lib/dpkg/status); [ -f "$h" ] && awk '/^Status: hold ok installed/{n++} END{print "Held packages: " (n+0)}' "$h" || printf 'Held packages: inspect with apt-mark showhold\n'
      p=$(repo_v86_join "$r" /etc/apt/preferences.d); [ -d "$p" ] && printf 'Pin files: %s\n' "$(find "$p" -type f 2>/dev/null | wc -l | tr -d ' ')" || printf 'Pin files: 0\n';;
    apk) w=$(repo_v86_join "$r" /etc/apk/world); [ -f "$w" ] && printf 'World constraints: %s\n' "$(grep -Ec '[<>=~]' "$w" 2>/dev/null || true)" || printf 'World file unavailable\n';;
    pacman) c=$(repo_v86_join "$r" /etc/pacman.conf); [ -f "$c" ] && grep -E '^[[:space:]]*(IgnorePkg|HoldPkg)' "$c" 2>/dev/null || printf 'No IgnorePkg/HoldPkg entries detected\n';;
    dnf|yum) c=$(repo_v86_join "$r" /etc/dnf/dnf.conf); [ -f "$c" ] && grep -E '^[[:space:]]*exclude=' "$c" 2>/dev/null || printf 'No global excludes detected\n';;
    xbps) d=$(repo_v86_join "$r" /etc/xbps.d); [ -d "$d" ] && grep -R '^[[:space:]]*holdpkg=' "$d" 2>/dev/null || printf 'No holdpkg entries detected\n';;
    emerge) c=$(repo_v86_join "$r" /etc/portage/package.mask); [ -e "$c" ] && printf 'Package masks configured\n' || printf 'No package.mask detected\n';;
    zypper) printf 'Locks: inspect with zypper locks\n';;
    *) printf 'No normalized package policy adapter is available.\n';;
  esac
}

repo_v86_hold(){
  r=${1:-/}; pkg=${2:-}; [ -n "$pkg" ] || return 2; case $pkg in *[!A-Za-z0-9+_.:@-]*) return 2;; esac
  pm=$(repo_v86_manager "$r")
  case $pm in
    apt) [ "$r" = / ] && apt-mark hold "$pkg" || chroot "$r" apt-mark hold "$pkg";;
    apk) w=$(repo_v86_join "$r" /etc/apk/world); grep -qx "$pkg" "$w" 2>/dev/null || printf '%s\n' "$pkg" >>"$w";;
    pacman) c=$(repo_v86_join "$r" /etc/pacman.conf); grep -q "^IgnorePkg.*\b$pkg\b" "$c" 2>/dev/null || printf '\nIgnorePkg = %s\n' "$pkg" >>"$c";;
    xbps) c=$(repo_v86_join "$r" /etc/xbps.d/99-ish-aok-holds.conf); mkdir -p "$(dirname "$c")"; printf 'holdpkg=%s\n' "$pkg" >>"$c";;
    dnf|yum) c=$(repo_v86_join "$r" /etc/dnf/dnf.conf); [ -f "$c" ] || c=$(repo_v86_join "$r" /etc/yum.conf); printf '\nexclude=%s\n' "$pkg" >>"$c";;
    *) echo "Package holds are not implemented for $pm" >&2; return 1;;
  esac
}

repo_v86_snapshot(){
  r=$(repo_v86_root "${1:-/}") || return 1; id=$(date +%Y%m%d-%H%M%S); out="$V86_REPO_STATE/snapshot-$id.tsv"; : >"$out"
  for rel in $(repo_v86_files "$r"); do full=$(repo_v86_join "$r" "$rel"); printf '%s\t%s\n' "$rel" "$(repo_v86_checksum "$full")" >>"$out"; done
  printf '%s\n' "$out"
}

repo_v86_report(){
  r=$(repo_v86_root "${1:-/}") || return 1; report_path="$V86_REPO_REPORTS/repository-$(date +%Y%m%d-%H%M%S).txt"
  { printf 'iSH-AOK Config 8.6.0 — Repository & Package Policy\n\n'; repo_v86_audit "$r"; } >"$report_path"
  printf '%s\n' "$report_path"
}
