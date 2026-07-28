#!/bin/sh

workflow_choose_and_run(){
  set --
  while IFS=$WORKFLOW_TAB read -r id name desc file; do set -- "$@" "$id" "$name — $desc"; done <<EOF_LIST
$(workflow_list)
EOF_LIST
  [ "$#" -gt 0 ] || { ui_msg Workflows 'No workflows are available.'; return; }
  id=$(ui_menu 'Run workflow' 'Choose a reusable workflow pipeline.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  workflow_run_named "$id"; rc=$?
  [ -n "${WORKFLOW_LAST_RUN:-}" ] && ui_text 'Workflow result' "Run: $WORKFLOW_LAST_RUN\nStatus: $([ "$rc" -eq 0 ] && echo success || echo failure)\nLog: $V74_RUN_DIR/$WORKFLOW_LAST_RUN/workflow.log"
  return "$rc"
}

workflow_runs_menu(){
  while :; do
    set --
    for d in $(ls -1dt "$V74_RUN_DIR"/* 2>/dev/null | head -n 50); do
      [ -d "$d" ] || continue
      id=$(basename "$d"); name=$(awk -F '\t' '$1=="name"{print $2}' "$d/meta.tsv"); result=$(awk -F '\t' '$1=="result"{print $2}' "$d/meta.tsv")
      set -- "$@" "$id" "${name:-workflow} [${result:-running}]"
    done
    [ "$#" -gt 0 ] || { ui_msg 'Workflow history' 'No workflow runs have been recorded.'; return; }
    id=$(ui_menu 'Workflow history' 'Choose a workflow run.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    c=$(ui_menu "$id" 'Inspect artifacts, logs, or rollback data.' log 'View workflow log' status 'View step status' artifacts 'List generated artifacts' rollback 'Restore rollback backup' delete 'Delete run record') || continue
    case $c in
      log) ui_text "$id log" "$(cat "$V74_RUN_DIR/$id/workflow.log" 2>/dev/null)";;
      status) ui_text "$id status" "$(awk -F '\t' '{printf "%-18s %-9s %s  %s\n",$1,$2,$3,$4}' "$V74_RUN_DIR/$id/status.tsv" 2>/dev/null)";;
      artifacts) ui_text "$id artifacts" "$(find "$V74_RUN_DIR/$id/artifacts" -maxdepth 2 -type f 2>/dev/null)";;
      rollback) workflow_restore_run "$id";;
      delete) ui_yesno 'Delete run' "Delete workflow run $id?" && rm -rf "$V74_RUN_DIR/$id";;
    esac
  done
}

workflow_create_wizard(){
  name=$(ui_input 'Create workflow' 'Workflow name') || return
  id=$(workflow_slug "$name"); file=$(workflow_pipeline_file "$id")
  [ -e "$file" ] && ! ui_yesno 'Create workflow' 'A workflow with this name exists. Replace it?' && return
  desc=$(ui_input 'Create workflow' 'Description' 'Custom iSH-AOK workflow') || return
  cat >"$file" <<EOF_WF
meta	name	$(workflow_clean "$name")
meta	description	$(workflow_clean "$desc")
EOF_WF
  while ui_yesno 'Create workflow' 'Add a step?'; do
    sid=$(ui_input 'Workflow step' 'Step ID' "step$(($(awk -F '\t' '$1==\"step\"{n++} END{print n+1}' "$file")))") || break
    title=$(ui_input 'Workflow step' 'Step title') || break
    handler=$(ui_input 'Workflow step' 'Shell function handler (for example: rootfs_health_report)') || break
    args=$(ui_input 'Workflow step' 'Arguments (supports {{ACTIVE_ROOTFS}} variables)' '') || break
    requires=$(ui_input 'Workflow step' 'Requirements, comma separated (rootfs,network,dns,package-manager,command:NAME)' '') || break
    condition=$(ui_input 'Workflow step' 'Condition KEY=value, or blank' '') || break
    rollback=$(ui_input 'Workflow step' 'Files/directories to back up before step, comma separated' '') || break
    artifact=$(ui_input 'Workflow step' 'Artifact path to retain after success, or blank' '') || break
    printf 'step\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(workflow_clean "$sid")" "$(workflow_clean "$title")" "$(workflow_clean "$handler")" "$(workflow_clean "$args")" "$(workflow_clean "$requires")" "$(workflow_clean "$condition")" "$(workflow_clean "$rollback")" "$(workflow_clean "$artifact")" >>"$file"
  done
  activity_add workflow "Created workflow $name"
  ui_msg 'Create workflow' "Saved: $file"
}

workflow_manage_custom(){
  while :; do
    set --
    for f in "$V74_PIPELINE_DIR"/*.workflow; do [ -r "$f" ] || continue; id=$(basename "$f" .workflow); name=$(awk -F '\t' '$1=="meta"&&$2=="name"{print $3;exit}' "$f"); set -- "$@" "$id" "${name:-$id}"; done
    set -- "$@" create 'Create a new workflow'
    id=$(ui_menu 'Custom workflows' 'Create, edit, duplicate, or delete pipelines.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    [ "$id" = create ] && { workflow_create_wizard; continue; }
    file=$(workflow_pipeline_file "$id")
    c=$(ui_menu "$id" 'Manage custom workflow.' run 'Run workflow' edit 'Edit workflow definition' duplicate 'Duplicate workflow' delete 'Delete workflow') || continue
    case $c in
      run) workflow_run_file "$file";;
      edit) edit_file "$file";;
      duplicate) n=$(ui_input Duplicate 'New workflow name') || continue; cp "$file" "$(workflow_pipeline_file "$n")"; sed -i "s/^meta[[:space:]]*name[[:space:]].*/meta\tname\t$(workflow_clean "$n")/" "$(workflow_pipeline_file "$n")" 2>/dev/null || true;;
      delete) ui_yesno Delete "Delete $id?" && rm -f "$file";;
    esac
  done
}

workflow_artifacts_menu(){
  ui_text 'Workflow artifacts' "$(find "$V74_ARTIFACT_DIR" "$V74_RUN_DIR" -type f \( -name '*.log' -o -path '*/artifacts/*' \) 2>/dev/null | tail -n 200)"
}

workflow_engine_menu(){
  while :; do
    c=$(ui_menu 'Workflow Engine' 'Reusable pipelines with dependencies, conditions, logs, artifacts, and rollback.' \
      run 'Run a workflow' \
      custom 'Create or manage custom workflows' \
      history 'Workflow history and rollback' \
      artifacts 'Artifact browser' \
      report 'Workflow engine report') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      run) workflow_choose_and_run;;
      custom) workflow_manage_custom;;
      history) workflow_runs_menu;;
      artifacts) workflow_artifacts_menu;;
      report) ui_text 'Workflow engine report' "$(workflow_report)";;
    esac
  done
}
