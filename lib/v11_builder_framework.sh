#!/bin/sh
# v11.0.1 RootFS Builder framework: profiles, package sets, caches, validation,
# queue metadata, artifacts, and reproducible build manifests.

V1101_DATA_DIR=${V1101_DATA_DIR:-$ISH_AOK_CONFIG_ROOT/data/v11}
V1101_PROFILE_DIR=${V1101_PROFILE_DIR:-$V1101_DATA_DIR/profiles}
V1101_PACKAGE_SET_DIR=${V1101_PACKAGE_SET_DIR:-$V1101_DATA_DIR/package-sets}
V1101_STATE_DIR=${V1101_STATE_DIR:-$STATE_DIR/builder-v11}
V1101_QUEUE_DIR=${V1101_QUEUE_DIR:-$V1101_STATE_DIR/queue}
V1101_MANIFEST_DIR=${V1101_MANIFEST_DIR:-$V1101_STATE_DIR/manifests}
V1101_REPORT_DIR=${V1101_REPORT_DIR:-$REPORT_DIR/builder-v11}
V1101_CACHE_ROOT=${V1101_CACHE_ROOT:-${ISH_AOK_CACHE_ROOT:-/var/cache/ish-aok-config}}
V1101_CACHE_KEYRINGS=$V1101_CACHE_ROOT/keyrings
V1101_CACHE_PACKAGES=$V1101_CACHE_ROOT/packages
V1101_CACHE_METADATA=$V1101_CACHE_ROOT/metadata
V1101_CACHE_MIRRORS=$V1101_CACHE_ROOT/mirrors
V1101_CACHE_BOOTSTRAP=$V1101_CACHE_ROOT/bootstrap
V1101_CACHE_ARTIFACTS=$V1101_CACHE_ROOT/artifacts

v1101_mkdir(){
  for d in "$@"; do
    [ -d "$d" ] || mkdir -p "$d" 2>/dev/null || run_root mkdir -p "$d" 2>/dev/null || return 1
  done
}

v1101_init(){
  v1101_mkdir "$V1101_STATE_DIR" "$V1101_QUEUE_DIR" "$V1101_MANIFEST_DIR" "$V1101_REPORT_DIR" || return 1
  v1101_mkdir "$V1101_CACHE_KEYRINGS" "$V1101_CACHE_PACKAGES" "$V1101_CACHE_METADATA" \
    "$V1101_CACHE_MIRRORS" "$V1101_CACHE_BOOTSTRAP" "$V1101_CACHE_ARTIFACTS" || true
}

v1101_profile_file(){ printf '%s/%s.profile\n' "$V1101_PROFILE_DIR" "$1"; }
v1101_package_set_file(){ printf '%s/%s.set\n' "$V1101_PACKAGE_SET_DIR" "$1"; }

v1101_kv_get(){
  file=$1 key=$2
  [ -r "$file" ] || return 1
  sed -n "s/^${key}=//p" "$file" | head -n 1
}

v1101_safe_id(){
  printf '%s' "$1" | tr '[:upper:] ' '[:lower:]_' | tr -cd 'a-z0-9._-'
}

v1101_profile_list(){
  for file in "$V1101_PROFILE_DIR"/*.profile; do
    [ -f "$file" ] || continue
    id=$(basename "$file" .profile)
    label=$(v1101_kv_get "$file" PROFILE_NAME 2>/dev/null || printf '%s' "$id")
    sets=$(v1101_kv_get "$file" PACKAGE_SETS 2>/dev/null || true)
    printf '%s|%s|%s|%s\n' "$id" "$label" "$sets" "$file"
  done
}

v1101_package_set_list(){
  for file in "$V1101_PACKAGE_SET_DIR"/*.set; do
    [ -f "$file" ] || continue
    id=$(v1101_kv_get "$file" ID 2>/dev/null || basename "$file" .set)
    label=$(v1101_kv_get "$file" LABEL 2>/dev/null || printf '%s' "$id")
    desc=$(v1101_kv_get "$file" DESCRIPTION 2>/dev/null || true)
    printf '%s|%s|%s|%s\n' "$id" "$label" "$desc" "$file"
  done
}

v1101_distro_package_key(){
  case $(v11_normalize_distro "${1:-${DISTRO_ID:-unknown}}") in
    alpine) printf PACKAGES_ALPINE;; arch) printf PACKAGES_ARCH;; fedora) printf PACKAGES_FEDORA;;
    void) printf PACKAGES_VOID;; gentoo) printf PACKAGES_GENTOO;; *) printf PACKAGES_COMMON;;
  esac
}

v1101_set_packages_direct(){
  id=$1 distro=${2:-${V102_DISTRO:-${DISTRO_ID:-unknown}}}
  file=$(v1101_package_set_file "$id")
  [ -r "$file" ] || return 1
  key=$(v1101_distro_package_key "$distro")
  packages=$(v1101_kv_get "$file" "$key" 2>/dev/null || true)
  [ -n "$packages" ] || packages=$(v1101_kv_get "$file" PACKAGES_COMMON 2>/dev/null || true)
  printf '%s\n' "$packages"
}

v1101_resolve_package_set(){
  id=$1 distro=${2:-${V102_DISTRO:-${DISTRO_ID:-unknown}}} seen=${3:-}
  case " $seen " in *" $id "*) return 0;; esac
  file=$(v1101_package_set_file "$id")
  [ -r "$file" ] || return 1
  includes=$(v1101_kv_get "$file" INCLUDES 2>/dev/null || true)
  for parent in $(printf '%s' "$includes" | tr ',' ' '); do
    (v1101_resolve_package_set "$parent" "$distro" "$seen $id")
  done
  v1101_set_packages_direct "$id" "$distro"
}

v1101_packages_for_sets(){
  sets=$1 distro=${2:-${V102_DISTRO:-${DISTRO_ID:-unknown}}}
  for id in $(printf '%s' "$sets" | tr ',' ' '); do
    [ -n "$id" ] && v1101_resolve_package_set "$id" "$distro"
  done | tr ' ' '\n' | sed '/^$/d' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/ $//'
}

v1101_active_profile_file(){
  [ -n "${V1101_ACTIVE_PROFILE:-}" ] && [ -r "$V1101_ACTIVE_PROFILE" ] && { printf '%s\n' "$V1101_ACTIVE_PROFILE"; return; }
  profile=${V89_ACTIVE_PROFILE:-standard}
  file=$(v1101_profile_file "$profile")
  [ -r "$file" ] && printf '%s\n' "$file" || v1101_profile_file standard
}

v1101_apply_profile(){
  id=$1 file=$(v1101_profile_file "$id")
  [ -r "$file" ] || return 1
  V1101_ACTIVE_PROFILE=$file; export V1101_ACTIVE_PROFILE
  V89_ACTIVE_PROFILE=$id; export V89_ACTIVE_PROFILE
  sets=$(v1101_kv_get "$file" PACKAGE_SETS 2>/dev/null || printf standard)
  distro=${V102_DISTRO:-$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO 2>/dev/null || printf unknown)}
  packages=$(v1101_packages_for_sets "$sets" "$distro")
  if [ -n "${V87_BUILD_PROFILE:-}" ]; then
    v87_profile_defaults >/dev/null 2>&1 || true
    v87_profile_set "$V87_BUILD_PROFILE" PROFILE_NAME "$(v1101_kv_get "$file" PROFILE_NAME)" 2>/dev/null || true
    v87_profile_set "$V87_BUILD_PROFILE" PACKAGES "$packages" 2>/dev/null || true
    v87_profile_set "$V87_BUILD_PROFILE" PACKAGE_SETS "$sets" 2>/dev/null || true
    for key in CREATE_ARCHIVE COMPRESSION ENABLE_SSH VALIDATE_AFTER_BUILD GENERATE_MANIFEST; do
      value=$(v1101_kv_get "$file" "$key" 2>/dev/null || true)
      [ -n "$value" ] && v87_profile_set "$V87_BUILD_PROFILE" "$key" "$value" 2>/dev/null || true
    done
  fi
  printf '%s\n' "$packages"
}

v1101_cache_report(){
  v1101_init >/dev/null 2>&1 || true
  printf 'RootFS Builder cache\n\n'
  for pair in "keyrings:$V1101_CACHE_KEYRINGS" "packages:$V1101_CACHE_PACKAGES" \
    "metadata:$V1101_CACHE_METADATA" "mirrors:$V1101_CACHE_MIRRORS" \
    "bootstrap:$V1101_CACHE_BOOTSTRAP" "artifacts:$V1101_CACHE_ARTIFACTS"; do
    label=${pair%%:*}; path=${pair#*:}
    count=$(find "$path" -type f 2>/dev/null | wc -l | awk '{print $1}')
    size=$(du -sh "$path" 2>/dev/null | awk '{print $1}'); [ -n "$size" ] || size=0
    printf '%-12s %-8s files=%-5s %s\n' "$label" "$size" "$count" "$path"
  done
}

v1101_profile_value(){
  key=$1
  if [ -n "${V87_BUILD_PROFILE:-}" ] && [ -r "$V87_BUILD_PROFILE" ]; then
    v87_profile_get "$V87_BUILD_PROFILE" "$key" 2>/dev/null || true
  fi
}

v1101_backend_command(){
  backend=$(v1101_profile_value BOOTSTRAP)
  case $backend in
    debootstrap) printf debootstrap;; mmdebstrap) printf mmdebstrap;; apk) printf apk;;
    pacstrap) printf pacstrap;; dnf) printf dnf;; xbps) printf xbps-install;; stage3) printf tar;;
    build_fs) printf build_fs;; *) printf '%s' "$backend";;
  esac
}

v1101_keyring_for_target(){
  distro=$(v11_normalize_distro "${1:-$(v1101_profile_value DISTRO)}")
  case $distro in
    ubuntu) printf '%s/ubuntu/ubuntu-archive-keyring.gpg' "${V111_KEYRING_CACHE:-$V1101_CACHE_KEYRINGS}";;
    debian) printf '%s/debian/debian-archive-keyring.gpg' "${V111_KEYRING_CACHE:-$V1101_CACHE_KEYRINGS}";;
    devuan) printf '%s/devuan/devuan-archive-keyring.gpg' "${V111_KEYRING_CACHE:-$V1101_CACHE_KEYRINGS}";;
    kali) printf '%s/kali/kali-archive-keyring.gpg' "${V111_KEYRING_CACHE:-$V1101_CACHE_KEYRINGS}";;
    *) return 1;;
  esac
}

v1101_validation_report(){
  v1101_init >/dev/null 2>&1 || true
  stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || printf now)
  report=$V1101_REPORT_DIR/preflight-$stamp.txt
  distro=$(v1101_profile_value DISTRO); release=$(v1101_profile_value RELEASE)
  arch=$(v1101_profile_value ARCH); dest=$(v1101_profile_value DEST)
  mirror=$(v1101_profile_value MIRROR); packages=$(v1101_profile_value PACKAGES)
  backend=$(v1101_profile_value BOOTSTRAP); cmd=$(v1101_backend_command)
  pass=0 warn=0 fail=0
  {
    printf '%s %s — RootFS Builder Preflight\n\n' "$PROGRAM" "$VERSION"
    printf 'Distribution: %s\nRelease: %s\nArchitecture: %s\nBackend: %s\nDestination: %s\n\n' "$distro" "$release" "$arch" "$backend" "$dest"
    if [ -n "$distro" ] && [ "$distro" != unknown ]; then printf '[PASS] target distribution selected\n'; pass=$((pass+1)); else printf '[FAIL] target distribution missing\n'; fail=$((fail+1)); fi
    if [ -n "$release" ]; then printf '[PASS] target release selected\n'; pass=$((pass+1)); else printf '[WARN] release is empty; backend default may be used\n'; warn=$((warn+1)); fi
    if [ -n "$arch" ]; then printf '[PASS] architecture selected: %s\n' "$arch"; pass=$((pass+1)); else printf '[FAIL] architecture missing\n'; fail=$((fail+1)); fi
    if [ -n "$dest" ] && [ "$dest" != / ]; then printf '[PASS] destination is separate from host: %s\n' "$dest"; pass=$((pass+1)); else printf '[FAIL] unsafe or empty destination\n'; fail=$((fail+1)); fi
    if [ -n "$cmd" ] && command -v "$cmd" >/dev/null 2>&1; then printf '[PASS] bootstrap command available: %s\n' "$cmd"; pass=$((pass+1)); else printf '[FAIL] bootstrap command unavailable: %s\n' "${cmd:-unknown}"; fail=$((fail+1)); fi
    if [ -n "$mirror" ]; then printf '[PASS] mirror configured: %s\n' "$mirror"; pass=$((pass+1)); else printf '[WARN] no explicit mirror; distribution default will be used\n'; warn=$((warn+1)); fi
    keyring=$(v1101_keyring_for_target "$distro" 2>/dev/null || true)
    if [ -n "$keyring" ]; then
      if [ -r "$keyring" ]; then printf '[PASS] target keyring cached: %s\n' "$keyring"; pass=$((pass+1));
      else printf '[FAIL] target keyring missing: %s\n' "$keyring"; fail=$((fail+1)); fi
    else printf '[PASS] target uses backend-native key management\n'; pass=$((pass+1)); fi
    pkg_count=$(printf '%s\n' "$packages" | awk '{print NF}')
    if [ "$pkg_count" -gt 0 ]; then printf '[PASS] package manifest contains %s packages\n' "$pkg_count"; pass=$((pass+1)); else printf '[WARN] package manifest is empty\n'; warn=$((warn+1)); fi
    parent=$(dirname "${dest:-/tmp}")
    if [ -d "$parent" ] && [ -w "$parent" ]; then printf '[PASS] destination parent is writable\n'; pass=$((pass+1)); else printf '[WARN] destination parent may require root privileges: %s\n' "$parent"; warn=$((warn+1)); fi
    free_kb=$(df -Pk "$parent" 2>/dev/null | awk 'NR==2{print $4}')
    if [ -n "$free_kb" ]; then
      if [ "$free_kb" -ge 524288 ]; then printf '[PASS] free space: %s KiB\n' "$free_kb"; pass=$((pass+1)); else printf '[WARN] low free space: %s KiB\n' "$free_kb"; warn=$((warn+1)); fi
    else printf '[WARN] free-space check unavailable\n'; warn=$((warn+1)); fi
    printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass" "$warn" "$fail"
    [ "$fail" -eq 0 ] && printf 'READY=yes\n' || printf 'READY=no\n'
  } >"$report"
  V1101_LAST_VALIDATION=$report; export V1101_LAST_VALIDATION
  printf '%s\n' "$report"
  [ "$fail" -eq 0 ]
}

v1101_checksum_file(){
  file=$1
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$file" | awk '{print $1}'
  else printf unavailable; fi
}

v1101_manifest_generate(){
  v1101_init >/dev/null 2>&1 || true
  stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || printf now)
  distro=$(v1101_profile_value DISTRO); release=$(v1101_profile_value RELEASE); arch=$(v1101_profile_value ARCH)
  id=$(v1101_safe_id "${distro:-rootfs}-${release:-unknown}-${arch:-unknown}-$stamp")
  manifest=$V1101_MANIFEST_DIR/$id.manifest
  artifact=${1:-}
  checksum=''
  [ -n "$artifact" ] && [ -f "$artifact" ] && checksum=$(v1101_checksum_file "$artifact")
  validation=${V1101_LAST_VALIDATION:-}
  {
    printf 'manifest_version=1\n'
    printf 'generated_by=%s %s\n' "$PROGRAM" "$VERSION"
    printf 'generated_at=%s\n' "$stamp"
    printf 'distribution=%s\n' "$distro"
    printf 'release=%s\n' "$release"
    printf 'architecture=%s\n' "$arch"
    printf 'profile=%s\n' "${V89_ACTIVE_PROFILE:-standard}"
    printf 'package_sets=%s\n' "$(v1101_profile_value PACKAGE_SETS)"
    printf 'packages=%s\n' "$(v1101_profile_value PACKAGES)"
    printf 'mirror=%s\n' "$(v1101_profile_value MIRROR)"
    printf 'bootstrap=%s\n' "$(v1101_profile_value BOOTSTRAP)"
    printf 'destination=%s\n' "$(v1101_profile_value DEST)"
    printf 'init=%s\n' "$(v1101_profile_value INIT)"
    printf 'shell=%s\n' "$(v1101_profile_value SHELL_PATH)"
    printf 'compression=%s\n' "$(v1101_profile_value COMPRESSION)"
    printf 'artifact=%s\n' "$artifact"
    printf 'sha256=%s\n' "$checksum"
    printf 'validation_report=%s\n' "$validation"
  } >"$manifest"
  V1101_LAST_MANIFEST=$manifest; export V1101_LAST_MANIFEST
  printf '%s\n' "$manifest"
}

v1101_queue_add(){
  v1101_init >/dev/null 2>&1 || return 1
  name=${1:-$(v1101_profile_value PROFILE_NAME)}
  stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || printf now)
  id=$(v1101_safe_id "${name:-build}-$stamp")
  file=$V1101_QUEUE_DIR/$id.job
  {
    printf 'JOB_ID=%s\nSTATUS=queued\nCREATED=%s\n' "$id" "$stamp"
    [ -r "${V87_BUILD_PROFILE:-}" ] && cat "$V87_BUILD_PROFILE"
  } >"$file"
  printf '%s\n' "$file"
}

v1101_queue_report(){
  v1101_init >/dev/null 2>&1 || true
  printf 'RootFS build queue\n\n'
  found=no
  for file in "$V1101_QUEUE_DIR"/*.job; do
    [ -f "$file" ] || continue; found=yes
    id=$(v1101_kv_get "$file" JOB_ID); status=$(v1101_kv_get "$file" STATUS)
    distro=$(v1101_kv_get "$file" DISTRO); release=$(v1101_kv_get "$file" RELEASE); arch=$(v1101_kv_get "$file" ARCH)
    printf '%-34s %-10s %s %s / %s\n' "$id" "$status" "$distro" "$release" "$arch"
  done
  [ "$found" = yes ] || printf 'Queue is empty.\n'
}

v1101_artifact_report(){
  v1101_init >/dev/null 2>&1 || true
  printf 'Build artifacts\n\n'
  found=no
  for dir in "$V1101_CACHE_ARTIFACTS" "$(v1101_profile_value ARTIFACT_DIR)"; do
    [ -d "$dir" ] || continue
    find "$dir" -maxdepth 1 -type f 2>/dev/null | while IFS= read -r file; do
      size=$(du -h "$file" 2>/dev/null | awk '{print $1}')
      printf '%-10s %s\n' "${size:-?}" "$file"
    done
    found=yes
  done
  [ "$found" = yes ] || printf 'No artifact directories are available.\n'
}
