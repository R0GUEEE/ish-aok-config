#!/bin/sh
# v11.1.0 resumable RootFS build pipeline.

V1110_BUILD_ROOT=${V1110_BUILD_ROOT:-${STATE_DIR:-/var/lib/ish-aok-config}/builds}
V1110_HISTORY=${V1110_HISTORY:-$V1110_BUILD_ROOT/history.tsv}
V1110_STAGE_ORDER='initialize plan repository keyrings bootstrap packages configure validate package cleanup'
V1110_BACKEND_ROOT=${V1110_BACKEND_ROOT:-$ISH_AOK_CONFIG_ROOT/backends}
V1110_DISTRO_DIR=${V1110_DISTRO_DIR:-$ISH_AOK_CONFIG_ROOT/data/v11/distributions}

v1110_now(){ date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date; }
v1110_id(){ date '+%Y%m%d-%H%M%S' 2>/dev/null || printf 'build-%s' "$$"; }
v1110_safe(){ printf '%s' "$1" | tr '[:upper:] /' '[:lower:]__' | tr -cd 'a-z0-9._-'; }
v1110_profile(){
  key=$1
  value=$(v1101_profile_value "$key" 2>/dev/null || true)
  if [ -z "$value" ] && [ -n "${V87_BUILD_PROFILE:-}" ] && [ -r "$V87_BUILD_PROFILE" ]; then
    value=$(sed -n "s/^${key}=//p" "$V87_BUILD_PROFILE" | tail -n 1)
  fi
  printf '%s\n' "$value"
}
v1110_state_get(){ sed -n "s/^$2=//p" "$1/state.env" 2>/dev/null | tail -n 1; }
v1110_state_set(){
  ws=$1 key=$2 value=$3 tmp=$1/.state.$$
  [ -f "$ws/state.env" ] || : >"$ws/state.env"
  awk -F= -v k="$key" '$1!=k{print}' "$ws/state.env" >"$tmp" 2>/dev/null || : >"$tmp"
  printf '%s=%s\n' "$key" "$value" >>"$tmp" && mv "$tmp" "$ws/state.env"
}
v1110_log(){
  ws=$1 stage=$2; shift 2
  line="$(v1110_now) [$stage] $*"
  printf '%s\n' "$line" >>"$ws/logs/builder.log"
  printf '%s\n' "$line" >>"$ws/logs/$stage.log"
}
v1110_workspace_create(){
  id=${1:-$(v1110_id)}; ws=$V1110_BUILD_ROOT/$(v1110_safe "$id")
  mkdir -p "$ws/logs" "$ws/cache" "$ws/rootfs" "$ws/artifacts" "$ws/stages" || return 1
  : >"$ws/state.env"
  v1110_state_set "$ws" BUILD_ID "$(basename "$ws")"
  v1110_state_set "$ws" STATUS planned
  v1110_state_set "$ws" CURRENT_STAGE initialize
  v1110_state_set "$ws" CREATED_AT "$(v1110_now)"
  v1110_snapshot_profile "$ws"
  printf '%s\n' "$ws"
}
v1110_snapshot_profile(){
  ws=$1
  {
    for key in DISTRO RELEASE ARCH BOOTSTRAP MIRROR DEST PACKAGES PACKAGE_SETS PROFILE_NAME INIT SHELL COMPRESSION CREATE_ARCHIVE; do
      printf '%s=%s\n' "$key" "$(v1110_profile "$key")"
    done
  } >"$ws/profile.env"
}
v1110_distribution_file(){ printf '%s/%s.conf\n' "$V1110_DISTRO_DIR" "$(v11_normalize_distro "$1")"; }
v1110_dist_get(){ file=$(v1110_distribution_file "$1"); sed -n "s/^$2=//p" "$file" 2>/dev/null | head -n 1; }
v1110_backend_name(){
  d=$(v1110_profile DISTRO); b=$(v1110_profile BOOTSTRAP)
  [ -n "$b" ] || b=$(v1110_dist_get "$d" BACKEND)
  case $b in mmdebstrap) printf debootstrap;; xbps-install) printf xbps;; build_fs|'') printf legacy;; *) printf '%s' "$b";; esac
}
v1110_backend_load(){
  name=${1:-$(v1110_backend_name)}; file=$V1110_BACKEND_ROOT/$name/backend.sh
  [ -r "$file" ] || file=$V1110_BACKEND_ROOT/legacy/backend.sh
  . "$file"
  V1110_ACTIVE_BACKEND=$name; export V1110_ACTIVE_BACKEND
}
v1110_hook_run(){
  hook=$1 ws=$2
  command -v v112_plugin_run_hook >/dev/null 2>&1 && v112_plugin_run_hook "$hook" "$ws" || return 1
  for f in "$ISH_AOK_CONFIG_ROOT"/plugins/enabled/*/hooks/$hook.sh "$ISH_AOK_CONFIG_ROOT"/plugins/*/hooks/$hook.sh "${V112_PLUGIN_ROOT:-/nonexistent}"/*/hooks/$hook.sh; do
    [ -r "$f" ] || continue
    v1110_log "$ws" hook "running $hook: $f"
    V1110_WORKSPACE=$ws V1110_HOOK=$hook sh "$f" "$ws" || return 1
  done
}
v1110_stage_done(){ [ -f "$1/stages/$2.done" ]; }
v1110_stage_mark(){ printf '%s\n' "$(v1110_now)" >"$1/stages/$2.done"; }
v1110_plan_report(){
  ws=$1 out=$ws/build-plan.txt
  distro=$(v1110_profile DISTRO); arch=$(v1110_profile ARCH); release=$(v1110_profile RELEASE)
  packages=$(v1110_profile PACKAGES); count=$(printf '%s\n' "$packages" | awk '{print NF}')
  backend=$(v1110_backend_name); keyring=$(v1101_keyring_for_target "$distro" 2>/dev/null || printf backend-native)
  {
    printf 'iSH-AOK RootFS Build Plan\n\n'
    printf 'Build ID: %s\nDistribution: %s\nRelease: %s\nArchitecture: %s\nBackend: %s\nMirror: %s\nDestination: %s\nKeyring: %s\nPackages: %s\nProfile: %s\n' \
      "$(basename "$ws")" "$distro" "$release" "$arch" "$backend" "$(v1110_profile MIRROR)" "$(v1110_profile DEST)" "$keyring" "$count" "$(v1110_profile PROFILE_NAME)"
  } >"$out"
  printf '%s\n' "$out"
}
v1110_stage_initialize(){ mkdir -p "$1/logs" "$1/cache" "$1/rootfs" "$1/artifacts"; }
v1110_stage_plan(){ v1110_plan_report "$1" >/dev/null; }
v1110_stage_repository(){ v1110_backend_load; backend_prepare "$1"; }
v1110_stage_keyrings(){ v1110_hook_run pre-bootstrap "$1" && backend_keyrings "$1"; }
v1110_stage_bootstrap(){ v1110_hook_run pre-bootstrap "$1" && backend_bootstrap "$1" && v1110_hook_run post-bootstrap "$1"; }
v1110_stage_packages(){ v1110_hook_run pre-package "$1" && backend_install_packages "$1" && v1110_hook_run post-package "$1"; }
v1110_stage_configure(){ backend_configure "$1"; }
v1110_stage_validate(){ v1110_hook_run pre-validation "$1" && backend_verify "$1" && v1110_hook_run post-validation "$1"; }
v1110_stage_package(){ v1110_hook_run pre-export "$1" && backend_package "$1" && v1110_hook_run post-export "$1"; }
v1110_stage_cleanup(){ backend_cleanup "$1"; }
v1110_run_stage(){
  ws=$1 stage=$2
  v1110_state_set "$ws" CURRENT_STAGE "$stage"; v1110_state_set "$ws" STATUS running
  v1110_log "$ws" "$stage" start
  "v1110_stage_$stage" "$ws" >>"$ws/logs/$stage.log" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then v1110_stage_mark "$ws" "$stage"; v1110_log "$ws" "$stage" complete; else v1110_state_set "$ws" STATUS failed; v1110_log "$ws" "$stage" "failed rc=$rc"; fi
  return "$rc"
}
v1110_history_add(){
  ws=$1 status=$2
  mkdir -p "$(dirname "$V1110_HISTORY")"; [ -f "$V1110_HISTORY" ] || printf 'build_id\tcreated\tdistro\trelease\tarch\tbackend\tstatus\tworkspace\n' >"$V1110_HISTORY"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(basename "$ws")" "$(v1110_state_get "$ws" CREATED_AT)" "$(v1110_profile DISTRO)" "$(v1110_profile RELEASE)" "$(v1110_profile ARCH)" "$(v1110_backend_name)" "$status" "$ws" >>"$V1110_HISTORY"
}
v1110_pipeline_run(){
  ws=$1
  v1110_backend_load || return 1
  for stage in $V1110_STAGE_ORDER; do
    v1110_stage_done "$ws" "$stage" && continue
    v1110_run_stage "$ws" "$stage" || { v1110_history_add "$ws" failed; return 1; }
  done
  v1110_state_set "$ws" STATUS complete; v1110_state_set "$ws" COMPLETED_AT "$(v1110_now)"
  v1110_history_add "$ws" complete
  v1101_manifest_generate >/dev/null 2>&1 || true
  return 0
}
v1110_pipeline_new(){ ws=$(v1110_workspace_create) || return 1; v1110_pipeline_run "$ws"; }
v1110_pipeline_resume(){ ws=$1; [ -d "$ws" ] || return 1; v1110_pipeline_run "$ws"; }
v1110_interrupted_list(){
  for ws in "$V1110_BUILD_ROOT"/*; do [ -d "$ws" ] || continue; status=$(v1110_state_get "$ws" STATUS); [ "$status" = failed ] || [ "$status" = running ] || continue; printf '%s|%s|%s\n' "$(basename "$ws")" "$status" "$(v1110_state_get "$ws" CURRENT_STAGE)"; done
}
v1110_history_report(){ [ -r "$V1110_HISTORY" ] && cat "$V1110_HISTORY" || printf 'No build history.\n'; }
