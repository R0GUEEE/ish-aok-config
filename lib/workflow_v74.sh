#!/bin/sh

V74_WORKFLOW_DIR=${V74_WORKFLOW_DIR:-$STATE_DIR/workflows}
V74_PIPELINE_DIR=$V74_WORKFLOW_DIR/pipelines
V74_RUN_DIR=$V74_WORKFLOW_DIR/runs
V74_ARTIFACT_DIR=$V74_WORKFLOW_DIR/artifacts
V74_TEMPLATE_DIR=${ISH_AOK_CONFIG_ROOT:-.}/workflows
WORKFLOW_TAB=$(printf '\t')
mkdir -p "$V74_PIPELINE_DIR" "$V74_RUN_DIR" "$V74_ARTIFACT_DIR" 2>/dev/null || true

workflow_now_id(){ date '+%Y%m%d-%H%M%S' 2>/dev/null || printf '%s' "$$"; }
workflow_now(){ date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date; }
workflow_clean(){ printf '%s' "$*" | tr '\t\r\n' '   '; }
workflow_slug(){ printf '%s' "$1" | tr '[:upper:] ' '[:lower:]_' | sed 's/[^a-z0-9_.-]/_/g;s/__\+/_/g'; }
workflow_pipeline_file(){ printf '%s/%s.workflow\n' "$V74_PIPELINE_DIR" "$(workflow_slug "$1")"; }
workflow_builtin_file(){ printf '%s/%s.workflow\n' "$V74_TEMPLATE_DIR" "$(workflow_slug "$1")"; }

workflow_var_get(){
  case $1 in
    ACTIVE_ROOTFS) active_rootfs;;
    ROOTFS_ARCH) r=$(active_rootfs); [ -n "$r" ] && rootfs_meta_get "$r" arch || printf '%s' unknown;;
    PACKAGE_MANAGER) r=$(active_rootfs); [ -n "$r" ] && rootfs_meta_get "$r" package_manager || printf '%s' "$PKG_MGR";;
    INIT_SYSTEM) r=$(active_rootfs); [ -n "$r" ] && rootfs_meta_get "$r" init || printf '%s' "$INIT_SYSTEM";;
    HOST_ARCH) printf '%s' "$ARCH";;
    BUILD_DATE) date '+%Y-%m-%d' 2>/dev/null || date;;
    STATE_DIR) printf '%s' "$STATE_DIR";;
    REPORT_DIR) printf '%s' "$REPORT_DIR";;
    *) eval "printf '%s' \"\${$1:-}\"";;
  esac
}

workflow_expand(){
  value=$1
  for key in ACTIVE_ROOTFS ROOTFS_ARCH PACKAGE_MANAGER INIT_SYSTEM HOST_ARCH BUILD_DATE STATE_DIR REPORT_DIR; do
    val=$(workflow_var_get "$key")
    value=$(printf '%s' "$value" | sed "s#{{${key}}}#$(printf '%s' "$val" | sed 's/[&\\]/\\&/g')#g")
  done
  printf '%s' "$value"
}

workflow_dependency_check(){
  dep=$1
  case $dep in
    '') return 0;;
    rootfs) r=$(active_rootfs); [ -n "$r" ] && [ -d "$r" ];;
    root) is_root || have sudo || have doas;;
    network) have ping && ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || have wget || have curl;;
    dns) getent hosts deb.devuan.org >/dev/null 2>&1 || nslookup deb.devuan.org >/dev/null 2>&1;;
    mounted-proc) r=$(active_rootfs); [ -n "$r" ] && [ -r "$r/proc/meminfo" ];;
    mounted-dev) r=$(active_rootfs); [ -n "$r" ] && [ -e "$r/dev/null" ];;
    package-manager) pm=$(workflow_var_get PACKAGE_MANAGER); [ -n "$pm" ] && [ "$pm" != unknown ];;
    command:*) have "${dep#command:}";;
    file:*) [ -e "$(workflow_expand "${dep#file:}")" ];;
    *) return 1;;
  esac
}

workflow_requirements_check(){
  reqs=$1; missing=''
  oldIFS=$IFS; IFS=','
  for dep in $reqs; do dep=$(printf '%s' "$dep" | sed 's/^ *//;s/ *$//'); [ -n "$dep" ] || continue; workflow_dependency_check "$dep" || missing="$missing${missing:+, }$dep"; done
  IFS=$oldIFS
  [ -z "$missing" ] || { WORKFLOW_MISSING=$missing; return 1; }
}

workflow_condition_true(){
  expr=$1
  [ -z "$expr" ] && return 0
  key=$(printf '%s' "$expr" | awk -F '=' '{print $1}')
  value=$(printf '%s' "$expr" | awk -F '=' '{sub(/^[^=]*=/,"");print}')
  actual=$(workflow_var_get "$key")
  [ "$actual" = "$value" ]
}

workflow_backup_targets(){
  targets=$1; run_dir=$2
  [ -n "$targets" ] || return 0
  mkdir -p "$run_dir/rollback" 2>/dev/null || true
  oldIFS=$IFS; IFS=','
  for target in $targets; do
    target=$(workflow_expand "$target")
    [ -e "$target" ] || continue
    rel=$(printf '%s' "$target" | sed 's#^/##;s#/#__#g')
    cp -a "$target" "$run_dir/rollback/$rel" 2>/dev/null || true
    printf '%s\t%s\n' "$target" "$rel" >>"$run_dir/rollback.tsv"
  done
  IFS=$oldIFS
}

workflow_restore_run(){
  run_id=$1; run_dir=$V74_RUN_DIR/$run_id
  [ -f "$run_dir/rollback.tsv" ] || { ui_msg Rollback 'No rollback data is available for this run.'; return 1; }
  ui_yesno Rollback "Restore files backed up by workflow run $run_id?" || return 1
  while IFS=$WORKFLOW_TAB read -r target rel; do
    [ -e "$run_dir/rollback/$rel" ] || continue
    rm -rf "$target" 2>/dev/null || as_root rm -rf "$target"
    cp -a "$run_dir/rollback/$rel" "$target" 2>/dev/null || as_root cp -a "$run_dir/rollback/$rel" "$target"
  done <"$run_dir/rollback.tsv"
  activity_add workflow "Rolled back $run_id"
  notification_add info "Workflow rollback completed: $run_id"
}

workflow_run_step(){
  handler=$1; args=$2; log_file=$3
  expanded=$(workflow_expand "$args")
  command -v "$handler" >/dev/null 2>&1 || { printf 'Missing handler: %s\n' "$handler" >>"$log_file"; return 127; }
  printf 'COMMAND: %s %s\n' "$handler" "$expanded" >>"$log_file"
  if [ -n "$expanded" ]; then
    # Arguments in workflow definitions are controlled by local project files.
    eval 'set -- ' "$expanded"
    "$handler" "$@" >>"$log_file" 2>&1
  else
    "$handler" >>"$log_file" 2>&1
  fi
}

workflow_run_file(){
  file=$1
  [ -r "$file" ] || { ui_msg Workflow "Workflow not found: $file"; return 1; }
  name=$(awk -F '\t' '$1=="meta"&&$2=="name"{print $3;exit}' "$file")
  [ -n "$name" ] || name=$(basename "$file" .workflow)
  run_id=$(workflow_now_id)-$(workflow_slug "$name")
  run_dir=$V74_RUN_DIR/$run_id; mkdir -p "$run_dir" "$run_dir/artifacts" 2>/dev/null || return 1
  log_file=$run_dir/workflow.log
  status_file=$run_dir/status.tsv
  printf 'run_id\t%s\nname\t%s\nstarted\t%s\nfile\t%s\n' "$run_id" "$name" "$(workflow_now)" "$file" >"$run_dir/meta.tsv"
  printf 'Workflow: %s\nRun ID: %s\nStarted: %s\n\n' "$name" "$run_id" "$(workflow_now)" >"$log_file"
  steps=$(awk -F '\t' '$1=="step"{n++} END{print n+0}' "$file")
  current=0; failed=0
  while IFS=$WORKFLOW_TAB read -r kind sid title handler args requires condition rollback artifact; do
    [ "$kind" = step ] || continue
    current=$((current+1)); started=$(date +%s 2>/dev/null || echo 0)
    printf '\n[%s/%s] %s\n' "$current" "$steps" "$title" >>"$log_file"
    if ! workflow_condition_true "$condition"; then
      printf '%s\tskipped\t%s\tcondition:%s\n' "$sid" "$title" "$condition" >>"$status_file"; continue
    fi
    if ! workflow_requirements_check "$requires"; then
      printf 'Missing dependencies: %s\n' "$WORKFLOW_MISSING" >>"$log_file"
      printf '%s\tfailure\t%s\tmissing:%s\n' "$sid" "$title" "$WORKFLOW_MISSING" >>"$status_file"; failed=1; break
    fi
    workflow_backup_targets "$rollback" "$run_dir"
    event_emit workflow.step.started "$run_id $sid"
    workflow_run_step "$handler" "$args" "$log_file"; rc=$?
    ended=$(date +%s 2>/dev/null || echo 0); elapsed=$((ended-started))
    if [ "$rc" -eq 0 ]; then
      printf '%s\tsuccess\t%s\t%s\n' "$sid" "$title" "$elapsed" >>"$status_file"
      [ -n "$artifact" ] && { expanded_artifact=$(workflow_expand "$artifact"); [ -e "$expanded_artifact" ] && cp -a "$expanded_artifact" "$run_dir/artifacts/" 2>/dev/null || true; }
    else
      printf '%s\tfailure\t%s\trc=%s elapsed=%s\n' "$sid" "$title" "$rc" "$elapsed" >>"$status_file"; failed=1
    fi
    event_emit workflow.step.finished "$run_id $sid rc=$rc"
    [ "$failed" -eq 0 ] || break
  done <"$file"
  printf 'finished\t%s\nresult\t%s\n' "$(workflow_now)" "$([ "$failed" -eq 0 ] && echo success || echo failure)" >>"$run_dir/meta.tsv"
  cp "$log_file" "$V74_ARTIFACT_DIR/$run_id.log" 2>/dev/null || true
  activity_add workflow "Ran $name ($run_id)"
  if [ "$failed" -eq 0 ]; then notification_add info "Workflow completed: $name"; else notification_add warning "Workflow failed: $name ($run_id)"; fi
  WORKFLOW_LAST_RUN=$run_id; export WORKFLOW_LAST_RUN
  return "$failed"
}

workflow_find_file(){
  id=$(workflow_slug "$1")
  for f in "$V74_PIPELINE_DIR/$id.workflow" "$V74_TEMPLATE_DIR/$id.workflow"; do [ -r "$f" ] && { printf '%s\n' "$f"; return 0; }; done
  return 1
}
workflow_run_named(){ file=$(workflow_find_file "$1") || { printf 'Unknown workflow: %s\n' "$1" >&2; return 2; }; workflow_run_file "$file"; }

workflow_list(){
  for f in "$V74_TEMPLATE_DIR"/*.workflow "$V74_PIPELINE_DIR"/*.workflow; do
    [ -r "$f" ] || continue
    id=$(basename "$f" .workflow); name=$(awk -F '\t' '$1=="meta"&&$2=="name"{print $3;exit}' "$f"); desc=$(awk -F '\t' '$1=="meta"&&$2=="description"{print $3;exit}' "$f")
    printf '%s\t%s\t%s\t%s\n' "$id" "${name:-$id}" "$desc" "$f"
  done
}

workflow_report(){
  printf 'Workflow Engine\n\nPipelines:\n'
  workflow_list | awk -F '\t' '{printf "%-24s %-28s %s\n",$1,$2,$3}'
  printf '\nRecent runs:\n'
  for d in $(ls -1dt "$V74_RUN_DIR"/* 2>/dev/null | head -n 10); do [ -d "$d" ] || continue; awk -F '\t' '$1=="name"{n=$2}$1=="result"{r=$2} END{printf "%-36s %-24s %s\n",FILENAME,n,r}' "$d/meta.tsv" | sed "s#$d/meta.tsv#$(basename "$d")#"; done
}

# Noninteractive task handlers used by built-in pipelines and scheduled execution.
workflow_task_refresh(){ r=$(active_rootfs); [ -n "$r" ] && rootfs_registry_refresh "$r"; }
workflow_task_health(){ rootfs_health_report >/dev/null; }
workflow_task_compatibility(){ compatibility_deep_report_v72 >/dev/null; }
workflow_task_manifest(){ r=$(active_rootfs); [ -d "$r" ] || return 1; out="$V74_ARTIFACT_DIR/manifest-$(rootfs_id "$r")-$(workflow_now_id).txt"; rootfs_manifest "$r" "$out"; printf '%s\n' "$out"; }
workflow_task_snapshot(){ r=$(active_rootfs); [ -d "$r" ] || return 1; out="$V74_ARTIFACT_DIR/$(rootfs_id "$r")-$(workflow_now_id).tar.gz"; tar -czf "$out" -C "$r" . && { have sha256sum && sha256sum "$out" >"$out.sha256" || true; printf '%s\n' "$out"; }; }
workflow_task_cleanup(){ r=$(active_rootfs); [ -d "$r" ] || return 1; rm -rf "$r/var/cache/apt/archives/"*.deb "$r/var/cache/apk/"* "$r/var/cache/pacman/pkg/"* "$r/tmp/"* "$r/var/tmp/"* 2>/dev/null || true; find "$r/var/log" -type f \( -name '*.gz' -o -name '*.old' -o -name '*.[0-9]' \) -delete 2>/dev/null || true; }
workflow_task_size_report(){ rootfs_optimization_report >/dev/null; }
workflow_task_boot_report(){ r=$(active_rootfs); [ -d "$r" ] || return 1; out="$V74_ARTIFACT_DIR/boot-$(rootfs_id "$r")-$(workflow_now_id).txt"; boot_profile_report >"$out"; printf '%s\n' "$out"; }
workflow_task_rootfs_report(){ rootfs_report_generate; }
