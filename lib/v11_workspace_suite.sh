#!/bin/sh
# iSH-AOK Config v11.3.0 — RootFS library, workspaces, snapshots, images, validation.

V113_VERSION=11.3.0
V113_STATE_ROOT=${V113_STATE_ROOT:-${XDG_DATA_HOME:-${HOME:-/root}/.local/share}/ish-aok-config/v11.3}
V113_LIBRARY=${V113_LIBRARY:-$V113_STATE_ROOT/rootfs/library.tsv}
V113_WORKSPACES=${V113_WORKSPACES:-$V113_STATE_ROOT/workspaces}
V113_SNAPSHOTS=${V113_SNAPSHOTS:-$V113_STATE_ROOT/snapshots}
V113_IMAGES=${V113_IMAGES:-$V113_STATE_ROOT/images/library.tsv}
V113_REPORTS=${V113_REPORTS:-$V113_STATE_ROOT/reports}
V113_OFFICIAL_PLUGINS=${V113_OFFICIAL_PLUGINS:-$ISH_AOK_CONFIG_ROOT/plugins/official}

v113_now(){ date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date; }
v113_id(){ date '+%Y%m%d-%H%M%S' 2>/dev/null || echo "$$"; }
v113_init(){
  mkdir -p "$(dirname "$V113_LIBRARY")" "$V113_WORKSPACES" "$V113_SNAPSHOTS/metadata" "$V113_SNAPSHOTS/archives" "$V113_SNAPSHOTS/checksums" "$(dirname "$V113_IMAGES")" "$V113_REPORTS" 2>/dev/null || return 1
  [ -f "$V113_LIBRARY" ] || printf 'id\tname\tpath\tdistro\trelease\tarch\tprofile\tcreated\tmodified\tvalidated\tsize_kb\tstatus\ttags\n' >"$V113_LIBRARY"
  [ -f "$V113_IMAGES" ] || printf 'id\tname\tpath\tdistro\trelease\tarch\tcompression\tprofile\tchecksum\tstatus\tcreated\n' >"$V113_IMAGES"
}
v113_safe_id(){ printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-'; }
v113_file_value(){ _f=$1 _k=$2; awk -F= -v k="$_k" '$1==k{sub(/^[^=]*=/,"");print;exit}' "$_f" 2>/dev/null; }
v113_os_value(){ _r=$1 _k=$2; [ -r "$_r/etc/os-release" ] && sed -n "s/^$_k=//p" "$_r/etc/os-release" | head -n1 | sed 's/^"//;s/"$//'; }
v113_arch(){ _r=$1; for _p in "$_r/var/lib/dpkg/arch" "$_r/etc/apk/arch"; do [ -r "$_p" ] && { head -n1 "$_p"; return; }; done; file "$_r/bin/sh" 2>/dev/null | sed -n 's/.*\(ARM aarch64\|x86-64\|Intel 80386\|RISC-V\).*/\1/p' | tr ' ' '-'; }
v113_size_kb(){ du -sk "$1" 2>/dev/null | awk '{print $1+0}'; }
v113_library_has_path(){ awk -F '\t' -v p="$1" 'NR>1&&$3==p{found=1}END{exit !found}' "$V113_LIBRARY"; }
v113_library_id_for_path(){ awk -F '\t' -v p="$1" 'NR>1&&$3==p{print $1;exit}' "$V113_LIBRARY"; }
v113_library_register(){
  v113_init || return 1; _path=$1; [ -d "$_path" ] || return 2
  case $_path in /|/etc|/usr|/var|/bin|/sbin) return 3;; esac
  _path=$(CDPATH= cd -- "$_path" 2>/dev/null && pwd) || return 2
  _id=$(v113_library_id_for_path "$_path"); [ -n "$_id" ] || _id=$(v113_safe_id "$(basename "$_path")-$(v113_id)")
  _name=${2:-$(basename "$_path")}; _d=$(v113_os_value "$_path" ID); _rel=$(v113_os_value "$_path" VERSION_CODENAME); [ -n "$_rel" ] || _rel=$(v113_os_value "$_path" VERSION_ID)
  _a=$(v113_arch "$_path"); [ -n "$_a" ] || _a=unknown; _profile=${3:-custom}; _now=$(v113_now); _size=$(v113_size_kb "$_path"); _status=registered
  _tmp=$V113_LIBRARY.tmp.$$
  awk -F '\t' -v OFS='\t' -v id="$_id" -v n="$_name" -v p="$_path" -v d="${_d:-unknown}" -v r="${_rel:-unknown}" -v a="$_a" -v pr="$_profile" -v now="$_now" -v sz="$_size" '
    NR==1{print;next} $1==id{print id,n,p,d,r,a,pr,$8,now,$10,sz,"registered",$13;done=1;next} {print} END{if(!done)print id,n,p,d,r,a,pr,now,now,"never",sz,"registered",""}' "$V113_LIBRARY" >"$_tmp" && mv "$_tmp" "$V113_LIBRARY"
  printf '%s\n' "$_id"
}
v113_library_remove(){ _id=$1; _tmp=$V113_LIBRARY.tmp.$$; awk -F '\t' -v OFS='\t' -v id="$_id" 'NR==1||$1!=id' "$V113_LIBRARY" >"$_tmp" && mv "$_tmp" "$V113_LIBRARY"; }
v113_library_scan(){
  v113_init || return 1
  for _base in "${AOK_ROOTFS_DIR:-${HOME:-/root}/rootfs}" "${HOME:-/root}/roots" /root; do
    [ -d "$_base" ] || continue
    find "$_base" -mindepth 1 -maxdepth 2 -type f -path '*/etc/os-release' 2>/dev/null | while IFS= read -r _os; do _r=${_os%/etc/os-release}; v113_library_has_path "$_r" || v113_library_register "$_r" >/dev/null 2>&1 || true; done
  done
}
v113_library_report(){ v113_init; awk -F '\t' 'BEGIN{printf "%-24s %-10s %-12s %-10s %-10s %s\n","NAME","DISTRO","RELEASE","ARCH","STATUS","PATH"} NR>1{printf "%-24s %-10s %-12s %-10s %-10s %s\n",$2,$4,$5,$6,$12,$3}' "$V113_LIBRARY"; }
v113_library_path(){ awk -F '\t' -v id="$1" 'NR>1&&($1==id||$2==id){print $3;exit}' "$V113_LIBRARY"; }
v113_library_info(){ awk -F '\t' -v id="$1" 'NR==1{for(i=1;i<=NF;i++)h[i]=$i;next} $1==id||$2==id{for(i=1;i<=NF;i++)printf "%s: %s\n",h[i],$i}' "$V113_LIBRARY"; }

v113_workspace_file(){ printf '%s/%s/workspace.conf\n' "$V113_WORKSPACES" "$1"; }
v113_workspace_create(){
  v113_init; _id=$(v113_safe_id "$1"); [ -n "$_id" ] || return 1; _root=$2; _template=${3:-minimal}; _dir=$V113_WORKSPACES/$_id; [ ! -e "$_dir" ] || return 2
  mkdir -p "$_dir" || return 1
  case $_template in
    cpp) _pkgs='git,build-essential,cmake,ninja-build,gdb';;
    rust) _pkgs='git,curl,build-essential,rustc,cargo';;
    python) _pkgs='git,python3,python3-pip,python3-venv';;
    go) _pkgs='git,golang';;
    node) _pkgs='git,nodejs,npm';;
    swift) _pkgs='git,clang,cmake,ninja-build,python3';;
    embedded) _pkgs='git,build-essential,cmake,ninja-build,gdb,openocd';;
    server) _pkgs='openssh-server,sudo,curl,rsync,cron,logrotate';;
    recovery) _pkgs='bash,coreutils,util-linux,procps,curl,rsync,tar,gzip,xz-utils';;
    *) _pkgs='bash,coreutils,ca-certificates,curl';;
  esac
  cat >"$_dir/workspace.conf" <<EOF2
id=$_id
name=$1
rootfs=$_root
template=$_template
shell=/bin/sh
editor=vi
prompt=
packages=$_pkgs
plugins=
created=$(v113_now)
EOF2
  : >"$_dir/environment"; : >"$_dir/mounts"; : >"$_dir/startup"; : >"$_dir/aliases"
  printf '%s\n' "$_id"
}
v113_workspace_list(){ v113_init; for _f in "$V113_WORKSPACES"/*/workspace.conf; do [ -r "$_f" ] || continue; printf '%-20s %-12s %-15s %s\n' "$(v113_file_value "$_f" id)" "$(v113_file_value "$_f" template)" "$(basename "$(v113_file_value "$_f" rootfs)")" "$(v113_file_value "$_f" name)"; done; }
v113_workspace_clone(){ _src=$(v113_workspace_file "$1"); [ -r "$_src" ] || return 1; _new=$(v113_safe_id "$2"); cp -R "$(dirname "$_src")" "$V113_WORKSPACES/$_new" || return 1; sed "s/^id=.*/id=$_new/;s/^name=.*/name=$2/" "$V113_WORKSPACES/$_new/workspace.conf" >"$V113_WORKSPACES/$_new/workspace.conf.tmp" && mv "$V113_WORKSPACES/$_new/workspace.conf.tmp" "$V113_WORKSPACES/$_new/workspace.conf"; }
v113_workspace_export(){ _id=$1 _dest=$2; tar -czf "$_dest" -C "$V113_WORKSPACES" "$_id"; }
v113_workspace_delete(){ rm -rf "$V113_WORKSPACES/$(v113_safe_id "$1")"; }

v113_snapshot_create(){
  v113_init; _root=$1; _name=${2:-snapshot-$(v113_id)}; _id=$(v113_safe_id "$_name"); [ -d "$_root" ] || return 1
  _archive=$V113_SNAPSHOTS/archives/$_id.tar.gz; _meta=$V113_SNAPSHOTS/metadata/$_id.conf
  _paths='etc/passwd etc/group etc/hostname etc/hosts etc/resolv.conf etc/apt etc/apk etc/pacman.conf etc/yum.repos.d etc/ssh etc/profile etc/bash.bashrc root/.profile root/.bashrc var/lib/dpkg/status lib/apk/db/installed'
  (cd "$_root" && for _p in $_paths; do [ -e "$_p" ] && printf '%s\n' "$_p"; done | tar -czf "$_archive" -T -) || return 2
  _sum=$(sha256sum "$_archive" 2>/dev/null | awk '{print $1}'); [ -n "$_sum" ] || _sum=unavailable
  cat >"$_meta" <<EOF2
id=$_id
name=$_name
rootfs=$_root
archive=$_archive
checksum=$_sum
created=$(v113_now)
EOF2
  printf '%s  %s\n' "$_sum" "$(basename "$_archive")" >"$V113_SNAPSHOTS/checksums/$_id.sha256"
  printf '%s\n' "$_id"
}
v113_snapshot_list(){ for _m in "$V113_SNAPSHOTS"/metadata/*.conf; do [ -r "$_m" ] || continue; printf '%-24s %-20s %s\n' "$(v113_file_value "$_m" id)" "$(v113_file_value "$_m" created)" "$(v113_file_value "$_m" rootfs)"; done; }
v113_snapshot_restore(){ _id=$1 _target=$2; _m=$V113_SNAPSHOTS/metadata/$_id.conf; [ -r "$_m" ] || return 1; _a=$(v113_file_value "$_m" archive); [ -r "$_a" ] || return 2; mkdir -p "$_target" && tar -xzf "$_a" -C "$_target"; }
v113_snapshot_validate(){ _id=$1; _m=$V113_SNAPSHOTS/metadata/$_id.conf; [ -r "$_m" ] || return 1; _a=$(v113_file_value "$_m" archive); _want=$(v113_file_value "$_m" checksum); _got=$(sha256sum "$_a" 2>/dev/null | awk '{print $1}'); [ "$_want" = unavailable ] || [ "$_want" = "$_got" ]; }
v113_snapshot_delete(){ _id=$1; rm -f "$V113_SNAPSHOTS/metadata/$_id.conf" "$V113_SNAPSHOTS/archives/$_id.tar.gz" "$V113_SNAPSHOTS/checksums/$_id.sha256"; }

v113_package_manager(){ _r=$1; [ -x "$_r/usr/bin/apt-get" ] && echo apt; [ -x "$_r/sbin/apk" ] && echo apk; [ -x "$_r/usr/bin/pacman" ] && echo pacman; [ -x "$_r/usr/bin/dnf" ] && echo dnf; [ -x "$_r/usr/bin/xbps-install" ] && echo xbps; }
v113_package_command(){ _r=$1 _op=$2 _pkg=$3; _pm=$(v113_package_manager "$_r" | head -n1); case $_pm:$_op in apt:install) echo "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y $_pkg";; apt:remove) echo "apt-get remove -y $_pkg";; apk:install) echo "apk add $_pkg";; apk:remove) echo "apk del $_pkg";; pacman:install) echo "pacman -Sy --noconfirm $_pkg";; pacman:remove) echo "pacman -R --noconfirm $_pkg";; dnf:install) echo "dnf install -y $_pkg";; dnf:remove) echo "dnf remove -y $_pkg";; xbps:install) echo "xbps-install -Sy $_pkg";; xbps:remove) echo "xbps-remove -Ry $_pkg";; *) return 1;; esac; }
v113_package_apply(){ _root=$1 _op=$2 _pkg=$3; _cmd=$(v113_package_command "$_root" "$_op" "$_pkg") || return 1; [ "${V113_DRY_RUN:-0}" = 1 ] && { printf '%s: %s\n' "$_root" "$_cmd"; return; }; chroot "$_root" /bin/sh -c "$_cmd"; }

v113_compare(){
  _a=$1 _b=$2 _out=${3:-$V113_REPORTS/compare-$(v113_id).txt}; mkdir -p "$(dirname "$_out")"
  {
    echo "RootFS comparison"; echo "A: $_a"; echo "B: $_b"; echo
    for _f in etc/os-release etc/passwd etc/group etc/hostname etc/resolv.conf etc/apt/sources.list etc/apk/repositories etc/pacman.conf; do
      echo "== $_f =="; diff -u "$_a/$_f" "$_b/$_f" 2>/dev/null || true; echo
    done
    echo '== package database =='
    if [ -r "$_a/var/lib/dpkg/status" ] && [ -r "$_b/var/lib/dpkg/status" ]; then
      awk '/^Package:/{print $2}' "$_a/var/lib/dpkg/status" | sort >"$_out.a.$$"; awk '/^Package:/{print $2}' "$_b/var/lib/dpkg/status" | sort >"$_out.b.$$"; diff -u "$_out.a.$$" "$_out.b.$$" || true; rm -f "$_out.a.$$" "$_out.b.$$"
    fi
  } >"$_out"
  printf '%s\n' "$_out"
}

v113_validate_rootfs(){
  _r=$1 _out=${2:-$V113_REPORTS/validation-$(v113_id).txt}; _pass=0 _warn=0 _fail=0
  v113_check(){ _label=$1 _mode=$2 _path=$3; if [ "$_mode" = x ]; then [ -x "$_r/$_path" ]; else [ -e "$_r/$_path" ]; fi; if [ $? -eq 0 ]; then echo "PASS  $_label"; _pass=$((_pass+1)); else echo "FAIL  $_label ($_path)"; _fail=$((_fail+1)); fi; }
  {
    echo "iSH-AOK RootFS Validation — $(v113_now)"; echo "RootFS: $_r"; echo
    v113_check Filesystem d etc; v113_check Shell x bin/sh; v113_check Users f etc/passwd; v113_check Groups f etc/group; v113_check Identity f etc/os-release
    if [ -e "$_r/etc/apt/sources.list" ] || [ -e "$_r/etc/apk/repositories" ] || [ -e "$_r/etc/pacman.conf" ] || [ -d "$_r/etc/yum.repos.d" ]; then echo 'PASS  Repositories'; _pass=$((_pass+1)); else echo 'WARN  Repositories'; _warn=$((_warn+1)); fi
    if [ -e "$_r/etc/resolv.conf" ]; then echo 'PASS  DNS'; _pass=$((_pass+1)); else echo 'WARN  DNS'; _warn=$((_warn+1)); fi
    if [ -d "$_r/etc/ssh" ]; then echo 'PASS  SSH'; _pass=$((_pass+1)); else echo 'WARN  SSH'; _warn=$((_warn+1)); fi
    if [ -e "$_r/var/lib/dpkg/status" ] || [ -e "$_r/lib/apk/db/installed" ] || [ -d "$_r/var/lib/pacman/local" ] || [ -d "$_r/var/lib/rpm" ]; then echo 'PASS  Package database'; _pass=$((_pass+1)); else echo 'WARN  Package database'; _warn=$((_warn+1)); fi
    _total=$((_pass+_warn+_fail)); [ "$_total" -gt 0 ] || _total=1; _score=$(((_pass*100+_warn*50)/_total)); echo; echo "Passed: $_pass"; echo "Warnings: $_warn"; echo "Failed: $_fail"; echo "Overall score: $_score%"
  } >"$_out"
  printf '%s\n' "$_out"
}

v113_image_register(){
  v113_init; _p=$1; [ -f "$_p" ] || return 1; _name=${2:-$(basename "$_p")}; _id=$(v113_safe_id "$_name-$(v113_id)"); _sum=$(sha256sum "$_p" 2>/dev/null | awk '{print $1}'); _comp=none
  case $_p in *.tar.gz|*.tgz) _comp=gzip;; *.tar.xz) _comp=xz;; *.tar.zst|*.tar.zstd) _comp=zstd;; *.tar) _comp=tar;; esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$_id" "$_name" "$_p" unknown unknown unknown "$_comp" custom "${_sum:-unavailable}" registered "$(v113_now)" >>"$V113_IMAGES"; printf '%s\n' "$_id"
}
v113_image_report(){ awk -F '\t' 'BEGIN{printf "%-28s %-10s %-10s %s\n","NAME","FORMAT","STATUS","PATH"} NR>1{printf "%-28s %-10s %-10s %s\n",$2,$7,$10,$3}' "$V113_IMAGES"; }
v113_image_verify(){ _id=$1; awk -F '\t' -v id="$_id" 'NR>1&&($1==id||$2==id){print $3"\t"$9;exit}' "$V113_IMAGES" | while IFS="$(printf '\t')" read -r _p _want; do _got=$(sha256sum "$_p" 2>/dev/null | awk '{print $1}'); [ "$_want" = unavailable ] || [ "$_want" = "$_got" ]; done; }

v113_performance_report(){
  v113_init; _roots=$(awk 'END{print NR-1}' "$V113_LIBRARY"); _ws=$(find "$V113_WORKSPACES" -name workspace.conf 2>/dev/null | wc -l | tr -d ' '); _sn=$(find "$V113_SNAPSHOTS/archives" -type f 2>/dev/null | wc -l | tr -d ' '); _im=$(awk 'END{print NR-1}' "$V113_IMAGES")
  _state=$(du -sk "$V113_STATE_ROOT" 2>/dev/null | awk '{print $1+0}'); _cache=$(du -sk "${V1101_CACHE_ROOT:-/var/cache/ish-aok-config}" 2>/dev/null | awk '{print $1+0}')
  printf 'Registered RootFSes: %s\nWorkspaces: %s\nSnapshots: %s\nImages: %s\nState storage: %s KB\nBuilder cache: %s KB\n' "$_roots" "$_ws" "$_sn" "$_im" "$_state" "$_cache"
  [ "${_cache:-0}" -gt 524288 ] 2>/dev/null && echo 'Recommendation: Review or purge builder caches larger than 512 MB.'
}

v113_pipeline_register(){
  _ws=$1; _root=$_ws/rootfs; [ -d "$_root/etc" ] || return 0
  _profile=custom; [ -r "$_ws/profile.env" ] && _profile=$(v113_file_value "$_ws/profile.env" PROFILE)
  v113_library_register "$_root" "$(basename "$_ws")" "${_profile:-custom}" >/dev/null 2>&1 || true
  [ "${V113_AUTO_SNAPSHOT:-0}" = 1 ] && v113_snapshot_create "$_root" "initial-$(basename "$_ws")" >/dev/null 2>&1 || true
}

v113_library_update_field(){
  _id=$1 _field=$2 _value=$3 _tmp=$V113_LIBRARY.tmp.$$
  awk -F '\t' -v OFS='\t' -v id="$_id" -v field="$_field" -v val="$_value" 'NR==1{for(i=1;i<=NF;i++)if($i==field)n=i;print;next}{$1==id&&n{$n=val};print}' "$V113_LIBRARY" >"$_tmp" && mv "$_tmp" "$V113_LIBRARY"
}
v113_library_clone(){
  _id=$1 _dest=$2 _name=${3:-$(basename "$_dest")}; _src=$(v113_library_path "$_id"); [ -d "$_src" ] || return 1; [ ! -e "$_dest" ] || return 2
  mkdir -p "$(dirname "$_dest")" || return 1
  if command -v cp >/dev/null 2>&1; then cp -a "$_src" "$_dest" 2>/dev/null || cp -R "$_src" "$_dest" || return 1; fi
  v113_library_register "$_dest" "$_name" clone
}
v113_library_export(){
  _id=$1 _dest=$2; _src=$(v113_library_path "$_id"); [ -d "$_src" ] || return 1
  case $_dest in *.tar.xz) tar -cJf "$_dest" -C "$_src" .;; *.tar) tar -cf "$_dest" -C "$_src" .;; *) tar -czf "$_dest" -C "$_src" .;; esac
}
v113_library_delete_filesystem(){
  _id=$1; _p=$(v113_library_path "$_id"); [ -n "$_p" ] || return 1
  case $_p in /|/bin|/etc|/usr|/var|/root|/home|/opt|/AOK|/AOK/*) return 2;; esac
  [ -f "$_p/.ish-aok-protected" ] && return 3
  rm -rf -- "$_p" && v113_library_remove "$_id"
}
v113_bulk_package_apply(){
  _ids=$1 _op=$2 _pkg=$3 _failed=0; _oldifs=$IFS; IFS=,
  for _id in $_ids; do IFS=$_oldifs; _id=$(printf '%s' "$_id" | sed 's/^ *//;s/ *$//'); _p=$(v113_library_path "$_id"); if [ -z "$_p" ]; then echo "$_id: not found"; _failed=1; elif ! v113_package_apply "$_p" "$_op" "$_pkg"; then echo "$_id: failed"; _failed=1; fi; IFS=,; done
  IFS=$_oldifs; return "$_failed"
}
v113_workspace_launch_script(){
  _id=$1 _out=${2:-$V113_WORKSPACES/$_id/launch.sh}; _f=$(v113_workspace_file "$_id"); [ -r "$_f" ] || return 1; _d=$(dirname "$_f"); _root=$(v113_file_value "$_f" rootfs); _shell=$(v113_file_value "$_f" shell)
  cat >"$_out" <<EOF2
#!/bin/sh
ROOTFS='$_root'
[ -d "\$ROOTFS" ] || { echo 'RootFS not found' >&2; exit 1; }
while IFS= read -r line; do [ -n "\$line" ] && export "\$line"; done <'$_d/environment'
while IFS='|' read -r source target options; do
  [ -n "\$source" ] || continue
  mkdir -p "\$ROOTFS/\$target"
  mount --bind "\$source" "\$ROOTFS/\$target" 2>/dev/null || true
done <'$_d/mounts'
while IFS= read -r command; do [ -n "\$command" ] && chroot "\$ROOTFS" /bin/sh -c "\$command"; done <'$_d/startup'
exec chroot "\$ROOTFS" '${_shell:-/bin/sh}'
EOF2
  chmod +x "$_out"; printf '%s\n' "$_out"
}
v113_compare_format(){
  _a=$1 _b=$2 _format=${3:-text}; _base=$V113_REPORTS/compare-$(v113_id); _txt=$(v113_compare "$_a" "$_b" "$_base.txt") || return 1
  case $_format in
    markdown) { echo '# RootFS Comparison'; echo; sed 's/^== \(.*\) ==$/## \1/;s/^A: /- **A:** /;s/^B: /- **B:** /' "$_txt"; } >"$_base.md"; echo "$_base.md";;
    html) { echo '<!doctype html><meta charset="utf-8"><title>RootFS Comparison</title><pre>'; sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' "$_txt"; echo '</pre>'; } >"$_base.html"; echo "$_base.html";;
    *) echo "$_txt";;
  esac
}
v113_snapshot_compare(){
  _a=$V113_SNAPSHOTS/archives/$1.tar.gz _b=$V113_SNAPSHOTS/archives/$2.tar.gz _out=${3:-$V113_REPORTS/snapshot-compare-$(v113_id).txt}; [ -r "$_a" ] && [ -r "$_b" ] || return 1
  tar -tzf "$_a" | sort >"$_out.a.$$"; tar -tzf "$_b" | sort >"$_out.b.$$"; diff -u "$_out.a.$$" "$_out.b.$$" >"$_out" || true; rm -f "$_out.a.$$" "$_out.b.$$"; echo "$_out"
}
