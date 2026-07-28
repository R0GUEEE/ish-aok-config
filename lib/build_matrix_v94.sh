#!/bin/sh
# v9.4 Cross-Distribution Build Matrix core
V94_DIR=${V94_DIR:-$STATE_DIR/build-v94}
V94_MATRIX_DIR=${V94_MATRIX_DIR:-$V94_DIR/matrices}
V94_TEMPLATE_DIR=${V94_TEMPLATE_DIR:-$V94_DIR/templates}
V94_GROUP_DIR=${V94_GROUP_DIR:-$V94_DIR/package-groups}
V94_BUILDER_DIR=${V94_BUILDER_DIR:-$V94_DIR/builders}
V94_PLUGIN_BUILDER_DIR=${V94_PLUGIN_BUILDER_DIR:-$STATE_DIR/plugins/builders}
mkdir -p "$V94_MATRIX_DIR" "$V94_TEMPLATE_DIR" "$V94_GROUP_DIR" "$V94_BUILDER_DIR" "$V94_PLUGIN_BUILDER_DIR" 2>/dev/null || true

v94_safe_id(){ printf '%s' "$1" | tr '[:upper:] ' '[:lower:]_' | tr -cd 'a-z0-9._-'; }
v94_profile_value(){ v87_profile_get "$1" "$2"; }
v94_profile_merge(){
  base=$1 child=$2 out=$3
  work="${out}.merge.$$"
  : >"$work"
  [ -f "$base" ] && cat "$base" >>"$work"
  [ -f "$child" ] || { mv "$work" "$out"; return 0; }
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in ''|'#'*) continue;; *=*) key=${line%%=*}; tmpf="${work}.filter"; grep -v "^${key}=" "$work" >"$tmpf" || true; mv "$tmpf" "$work"; printf '%s\n' "$line" >>"$work";; esac
  done <"$child"
  mv "$work" "$out"
}
v94_profile_resolve(){ v94_profile_resolve_depth "$1" "$2" 0; }
v94_profile_resolve_depth(){ (
  src=$1 out=$2 depth=$3
  [ "$depth" -lt 16 ] || { printf 'Profile inheritance is too deep or cyclic: %s\n' "$src" >&2; return 1; }
  parent=$(v94_profile_value "$src" EXTENDS)
  if [ -n "$parent" ]; then
    case $parent in /*) base=$parent;; *) base="$V89_PROFILE_LIBRARY/$parent.profile"; [ -f "$base" ] || base="$V94_TEMPLATE_DIR/$parent.profile";; esac
    [ -f "$base" ] || { printf 'Parent profile not found: %s\n' "$parent" >&2; return 1; }
    parent_out="${out}.parent.$depth"
    v94_profile_resolve_depth "$base" "$parent_out" $((depth+1)) || return
    v94_profile_merge "$parent_out" "$src" "$out"
    rm -f "$parent_out"
  else cp "$src" "$out"; fi
); }

v94_install_package_groups(){
  [ -f "$V94_GROUP_DIR/development.map" ] || cat >"$V94_GROUP_DIR/development.map" <<'EOF_G'
debian|build-essential git curl wget pkg-config
devuan|build-essential git curl wget pkg-config
ubuntu|build-essential git curl wget pkg-config
alpine|build-base git curl wget pkgconf
arch|base-devel git curl wget
void|base-devel git curl wget
fedora|gcc gcc-c++ make git curl wget pkgconf-pkg-config
ultramarine|gcc gcc-c++ make git curl wget pkgconf-pkg-config
EOF_G
  [ -f "$V94_GROUP_DIR/server.map" ] || cat >"$V94_GROUP_DIR/server.map" <<'EOF_G'
debian|openssh-server sudo ca-certificates cron logrotate
devuan|openssh-server sudo ca-certificates cron logrotate
ubuntu|openssh-server sudo ca-certificates cron logrotate
alpine|openssh sudo ca-certificates dcron logrotate
arch|openssh sudo ca-certificates cronie logrotate
void|openssh sudo ca-certificates cronie logrotate
fedora|openssh-server sudo ca-certificates cronie logrotate
EOF_G
}
v94_group_resolve(){ group=$1 distro=$2; v94_install_package_groups; f="$V94_GROUP_DIR/$group.map"; [ -f "$f" ] || return 1; awk -F'|' -v d="$distro" '$1==d{print $2; exit}' "$f"; }
v94_profile_expand_groups(){
  profile=$1; distro=$(v94_profile_value "$profile" DISTRO); groups=$(v94_profile_value "$profile" PACKAGE_GROUPS); pkgs=$(v94_profile_value "$profile" PACKAGES)
  for g in $groups; do mapped=$(v94_group_resolve "$g" "$distro" 2>/dev/null || true); [ -n "$mapped" ] && pkgs="$pkgs $mapped"; done
  printf '%s\n' "$pkgs" | awk '{for(i=1;i<=NF;i++) if(!seen[$i]++) printf "%s%s",sep,$i; print ""}'
}

v94_install_templates(){
  [ -f "$V94_TEMPLATE_DIR/minimal.profile" ] || cat >"$V94_TEMPLATE_DIR/minimal.profile" <<'EOF_T'
PROFILE_NAME=minimal
PACKAGE_GROUPS=
PACKAGES=ca-certificates curl wget bash nano
ENABLE_NETWORK=yes
REGISTER_ROOTFS=yes
CREATE_ARCHIVE=no
EOF_T
  [ -f "$V94_TEMPLATE_DIR/development.profile" ] || cat >"$V94_TEMPLATE_DIR/development.profile" <<'EOF_T'
EXTENDS=minimal
PROFILE_NAME=development
PACKAGE_GROUPS=development
CREATE_ARCHIVE=yes
EOF_T
  [ -f "$V94_TEMPLATE_DIR/server.profile" ] || cat >"$V94_TEMPLATE_DIR/server.profile" <<'EOF_T'
EXTENDS=minimal
PROFILE_NAME=server
PACKAGE_GROUPS=server
ENABLE_SSH=yes
ENABLE_SUDO=yes
EOF_T
  [ -f "$V94_TEMPLATE_DIR/ish-aok-optimized.profile" ] || cat >"$V94_TEMPLATE_DIR/ish-aok-optimized.profile" <<'EOF_T'
EXTENDS=minimal
PROFILE_NAME=ish-aok-optimized
INIT=sysvinit
LOCALE=C.UTF-8
TIMEZONE=UTC
COPY_DNS=yes
RUN_SECOND_STAGE=yes
COMPRESSION=zstd
EOF_T
}

v94_backend_command(){ case $1 in debootstrap) echo debootstrap;; mmdebstrap) echo mmdebstrap;; apk) echo apk;; pacstrap) echo pacstrap;; dnf) command -v dnf >/dev/null 2>&1 && echo dnf || echo yum;; xbps) echo xbps-install;; stage3) echo tar;; build_fs) echo /opt/AOK/build_fs;; *) echo "$1";; esac; }
v94_builder_register(){ id=$1; command=$2; title=$3; shift 3; file="$V94_BUILDER_DIR/$(v94_safe_id "$id").builder"; { printf 'ID=%s\nCOMMAND=%s\nTITLE=%s\n' "$id" "$command" "$title"; printf '%s\n' "$@"; } >"$file"; }
v94_install_builtin_builders(){
  v94_builder_register debootstrap debootstrap 'Debian-family debootstrap' 'DISTROS=debian devuan ubuntu' 'ARCHES=arm64 amd64 i386 riscv64'
  v94_builder_register apk apk 'Alpine apk root builder' 'DISTROS=alpine' 'ARCHES=arm64 x86_64 x86 riscv64'
  v94_builder_register pacstrap pacstrap 'Arch pacstrap builder' 'DISTROS=arch' 'ARCHES=arm64 x86_64'
  v94_builder_register dnf dnf 'DNF installroot builder' 'DISTROS=fedora ultramarine' 'ARCHES=arm64 x86_64'
  v94_builder_register xbps xbps-install 'Void XBPS builder' 'DISTROS=void' 'ARCHES=arm64 x86_64'
}
v94_builder_files(){ v94_install_builtin_builders; for f in "$V94_BUILDER_DIR"/*.builder "$V94_PLUGIN_BUILDER_DIR"/*.builder; do [ -f "$f" ] && printf '%s\n' "$f"; done; }
v94_capability_report(){
  printf 'iSH-AOK Config %s — Builder Capabilities\n\n' "$VERSION"
  v94_builder_files | while IFS= read -r f; do id=$(sed -n 's/^ID=//p' "$f"); title=$(sed -n 's/^TITLE=//p' "$f"); cmd=$(sed -n 's/^COMMAND=//p' "$f"); if command -v "$cmd" >/dev/null 2>&1 || [ -x "$cmd" ]; then status=available; else status=missing; fi; printf '%-15s %-10s %s (%s)\n' "$id" "$status" "$title" "$cmd"; done
}

v94_matrix_create(){ id=$(v94_safe_id "$1"); [ -n "$id" ] || return 1; file="$V94_MATRIX_DIR/$id.matrix"; [ -e "$file" ] || printf '# id|profile|distro|release|arch|status\n' >"$file"; printf '%s\n' "$file"; }
v94_matrix_add(){ file=$1 profile=$2 distro=$3 release=$4 arch=$5; id=$(v94_safe_id "$distro-$release-$arch-$(basename "$profile" .profile)"); printf '%s|%s|%s|%s|%s|pending\n' "$id" "$profile" "$distro" "$release" "$arch" >>"$file"; }
v94_matrix_validate(){
  file=$1; rc=0
  [ -f "$file" ] || return 1
  while IFS='|' read -r id profile distro release arch status; do case $id in ''|'#'*) continue;; esac; [ -f "$profile" ] || { printf '[FAIL] %s: profile missing: %s\n' "$id" "$profile"; rc=1; continue; }; [ -n "$distro" ] && [ -n "$release" ] && [ -n "$arch" ] || { printf '[FAIL] %s: incomplete target\n' "$id"; rc=1; continue; }; printf '[PASS] %s: %s %s %s\n' "$id" "$distro" "$release" "$arch"; done <"$file"; return "$rc"
}
v94_matrix_plan(){ file=$1; printf 'Build matrix: %s\n\n' "$file"; while IFS='|' read -r id profile distro release arch status; do case $id in ''|'#'*) continue;; esac; printf '%-28s %s %-12s %-8s profile=%s status=%s\n' "$id" "$distro" "$release" "$arch" "$(basename "$profile")" "$status"; done <"$file"; }
v94_matrix_execute(){
  file=$1; jobs=${V94_MATRIX_JOBS:-1}; [ "$jobs" = 1 ] || printf 'Parallel execution is disabled in iSH-AOK-safe mode; running sequentially.\n' >&2
  v94_matrix_validate "$file" || return 1
  out="$file.new"; : >"$out"
  while IFS='|' read -r id profile distro release arch status; do case $id in ''|'#'*) printf '%s\n' "$id${profile:+|$profile|$distro|$release|$arch|$status}" >>"$out"; continue;; esac
    resolved="$TMP_DIR/v94-$id.profile"; v94_profile_resolve "$profile" "$resolved" || { printf '%s|%s|%s|%s|%s|failed\n' "$id" "$profile" "$distro" "$release" "$arch" >>"$out"; continue; }
    v87_profile_set "$resolved" DISTRO "$distro"; v87_profile_set "$resolved" RELEASE "$release"; v87_profile_set "$resolved" ARCH "$arch"
    dest=$(v94_profile_value "$resolved" DEST); [ -n "$dest" ] || v87_profile_set "$resolved" DEST "/AOK/roots/$distro-$release-$arch"
    v87_profile_set "$resolved" PACKAGES "$(v94_profile_expand_groups "$resolved")"
    cp "$resolved" "$V87_BUILD_PROFILE"
    if v88_plan_generate >/dev/null && { [ "$DRY_RUN" = yes ] || v88_execute_plan; }; then ns=complete; else ns=failed; fi
    printf '%s|%s|%s|%s|%s|%s\n' "$id" "$profile" "$distro" "$release" "$arch" "$ns" >>"$out"
  done <"$file"
  mv "$out" "$file"
}
v94_matrix_report(){ printf 'iSH-AOK Config %s — Build Matrices\n\n' "$VERSION"; for f in "$V94_MATRIX_DIR"/*.matrix; do [ -f "$f" ] || continue; total=$(grep -vc '^#' "$f" 2>/dev/null || echo 0); printf '%s: %s target(s)\n' "$(basename "$f" .matrix)" "$total"; done; }
