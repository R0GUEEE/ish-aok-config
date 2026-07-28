#!/bin/sh

V80_STATE_DIR=${V80_STATE_DIR:-$STATE_DIR/platform-v80}
V80_PROJECTS_DIR=$V80_STATE_DIR/projects
V80_RECIPES_DIR=$V80_STATE_DIR/recipes
V80_PLUGIN_REPOS_DIR=$V80_STATE_DIR/plugin-repositories
V80_DOCS_DIR=$V80_STATE_DIR/generated-docs
mkdir -p "$V80_PROJECTS_DIR" "$V80_RECIPES_DIR" "$V80_PLUGIN_REPOS_DIR" "$V80_DOCS_DIR" 2>/dev/null || true

v80_safe_id(){ printf '%s' "$1" | tr ' /' '__' | tr -cd 'A-Za-z0-9._-'; }
v80_project_file(){ printf '%s/%s/project.conf' "$V80_PROJECTS_DIR" "$(v80_safe_id "$1")"; }
v80_conf_get(){ f=$1; k=$2; sed -n "s/^$k=//p" "$f" 2>/dev/null | tail -n 1; }
v80_conf_set(){ f=$1; k=$2; v=$3; mkdir -p "$(dirname "$f")"; t="$f.tmp.$$"; { grep -v "^$k=" "$f" 2>/dev/null || true; printf '%s=%s\n' "$k" "$v"; } >"$t" && mv "$t" "$f"; }

rootfs_project_create(){
  r=$(active_rootfs); [ -d "$r" ] || { ui_msg Projects 'Select a valid RootFS first.'; return 1; }
  name=$(ui_input 'Create RootFS project' 'Project name' "$(root_label)") || return
  id=$(v80_safe_id "$name"); [ -n "$id" ] || return 1
  d="$V80_PROJECTS_DIR/$id"; [ ! -e "$d" ] || { ui_msg Projects 'A project with that ID already exists.'; return 1; }
  mkdir -p "$d"/{metadata,snapshots,overlays,reports,workflows,artifacts,hooks} 2>/dev/null || mkdir -p "$d/metadata" "$d/snapshots" "$d/overlays" "$d/reports" "$d/workflows" "$d/artifacts" "$d/hooks"
  f="$d/project.conf"; printf 'id=%s\nname=%s\nrootfs=%s\ndistro=%s\narch=%s\ncreated=%s\n' "$id" "$name" "$r" "$(aok_root_os "$r")" "$(aok_root_arch "$r")" "$(date '+%Y-%m-%dT%H:%M:%S')" >"$f"
  rootfs_register "$r" >/dev/null 2>&1 || true; activity_add project "Created project $id for $r"; ui_msg Projects "Created: $d"
}
rootfs_project_list(){
  for f in "$V80_PROJECTS_DIR"/*/project.conf; do [ -f "$f" ] || continue; printf '%s\t%s\t%s\t%s\n' "$(v80_conf_get "$f" id)" "$(v80_conf_get "$f" name)" "$(v80_conf_get "$f" rootfs)" "$(v80_conf_get "$f" distro)"; done
}
rootfs_project_select(){ set --; while IFS="$(printf '\t')" read -r id name root distro; do [ -n "$id" ] && set -- "$@" "$id" "$name — $distro — $root"; done <<EOF_PROJECTS
$(rootfs_project_list)
EOF_PROJECTS
  [ "$#" -gt 0 ] || return 1; ui_menu 'RootFS projects' 'Select a project.' "$@";
}
rootfs_project_open(){ id=$(rootfs_project_select) || { ui_msg Projects 'No projects are registered.'; return; }; f=$(v80_project_file "$id"); r=$(v80_conf_get "$f" rootfs); [ -d "$r" ] && set_active_rootfs "$r"; ui_text 'RootFS project' "Project: $(v80_conf_get "$f" name)\nRootFS: $r\nDistribution: $(v80_conf_get "$f" distro)\nArchitecture: $(v80_conf_get "$f" arch)\nDirectory: $(dirname "$f")"; }
rootfs_project_export(){ id=$(rootfs_project_select) || return; d="$V80_PROJECTS_DIR/$id"; out="$AOK_SNAPSHOT_DIR/$id-project-$(date +%Y%m%d-%H%M%S).tar.gz"; run_capture 'Export project' tar -czf "$out" -C "$V80_PROJECTS_DIR" "$id"; [ -f "$out" ] && { have sha256sum && sha256sum "$out" >"$out.sha256"; ui_msg Projects "$out"; }; }
rootfs_projects_menu(){ while :; do c=$(ui_menu 'RootFS Projects' 'Group RootFS metadata, snapshots, overlays, reports, workflows and artifacts.' create 'Create project from active RootFS' open 'Browse/select projects' export 'Export project bundle' report 'Project registry report') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in create) rootfs_project_create;; open) rootfs_project_open;; export) rootfs_project_export;; report) ui_text Projects "$(rootfs_project_list)";; esac; done; }

build_recipe_create(){
  id=$(v80_safe_id "$(ui_input 'Build recipe' 'Recipe ID' devuan-minimal)") || return; [ -n "$id" ] || return
  f="$V80_RECIPES_DIR/$id.recipe"; distro=$(ui_input 'Build recipe' 'Distribution' devuan) || return; release=$(ui_input 'Build recipe' 'Release' excalibur) || return; arch=$(ui_input 'Build recipe' 'Architecture' arm64) || return; bootstrap=$(ui_input 'Build recipe' 'Bootstrap method' debootstrap) || return; packages=$(ui_input 'Build recipe' 'Packages (space separated)' 'ca-certificates curl bash nano openssh-server') || return
  printf 'id=%s\ndistro=%s\nrelease=%s\narch=%s\nbootstrap=%s\npackages=%s\npost_workflow=%s\n' "$id" "$distro" "$release" "$arch" "$bootstrap" "$packages" health_audit >"$f"; ui_msg Recipes "Saved: $f"
}
build_recipe_list(){ for f in "$V80_RECIPES_DIR"/*.recipe; do [ -f "$f" ] || continue; printf '%s\t%s\t%s\t%s\n' "$(v80_conf_get "$f" id)" "$(v80_conf_get "$f" distro)" "$(v80_conf_get "$f" release)" "$(v80_conf_get "$f" arch)"; done; }
build_recipe_select(){ set --; while IFS="$(printf '\t')" read -r id d r a; do [ -n "$id" ] && set -- "$@" "$id" "$d $r ($a)"; done <<EOF_RECIPES
$(build_recipe_list)
EOF_RECIPES
  [ "$#" -gt 0 ] || return 1; ui_menu 'Build recipes' 'Select a recipe.' "$@";
}
build_recipe_run(){ id=$(build_recipe_select) || return; f="$V80_RECIPES_DIR/$id.recipe"; ui_text 'Recipe execution plan' "Recipe: $id\nDistribution: $(v80_conf_get "$f" distro)\nRelease: $(v80_conf_get "$f" release)\nArchitecture: $(v80_conf_get "$f" arch)\nBootstrap: $(v80_conf_get "$f" bootstrap)\nPackages: $(v80_conf_get "$f" packages)\n\nOpen Builder Studio to execute this plan with existing validated builders."; aok_confirm 'Open Builder Studio now?' && aok_builder_studio; }
build_recipe_export(){ id=$(build_recipe_select) || return; cp "$V80_RECIPES_DIR/$id.recipe" "$CURRENT_HOME/$id.recipe" && ui_msg Recipes "$CURRENT_HOME/$id.recipe"; }
build_recipes_menu(){ while :; do c=$(ui_menu 'Build Recipes' 'Create reusable, version-control-friendly RootFS build plans.' create 'Create recipe' browse 'Browse recipes' run 'Review and run recipe' export 'Export recipe') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in create) build_recipe_create;; browse) id=$(build_recipe_select) || continue; ui_text Recipe "$(cat "$V80_RECIPES_DIR/$id.recipe")";; run) build_recipe_run;; export) build_recipe_export;; esac; done; }

multi_rootfs_health(){ out="$ROOTFS_REPORT_DIR/multi-health-$(date +%Y%m%d-%H%M%S).txt"; : >"$out"; old=$(active_rootfs); rootfs_registry_paths | while IFS= read -r r; do [ -d "$r" ] || continue; set_active_rootfs "$r"; h=$(rootfs_health_report); printf '\n===== %s =====\n' "$r" >>"$out"; grep -E 'Health score|\[FAIL\]' "$h" >>"$out" 2>/dev/null || true; done; set_active_rootfs "$old"; ui_text 'Multi-RootFS health' "$(cat "$out")"; }
multi_rootfs_package_compare(){ a=$(rootfs_select_registered) || return; b=$(rootfs_select_registered) || return; out="$ROOTFS_REPORT_DIR/package-compare-$(rootfs_id "$a")-$(rootfs_id "$b")-$(date +%Y%m%d-%H%M%S).txt"; rootfs_package_inventory "$a" >"$TMP_DIR/pka" 2>/dev/null || true; rootfs_package_inventory "$b" >"$TMP_DIR/pkb" 2>/dev/null || true; { echo "A: $a"; echo "B: $b"; echo; diff -u "$TMP_DIR/pka" "$TMP_DIR/pkb" 2>/dev/null || true; } >"$out"; ui_text 'Package comparison' "$(cat "$out")"; }
multi_rootfs_repo_sync(){ src=$(rootfs_select_registered) || return; dst=$(rootfs_select_registered) || return; [ "$src" != "$dst" ] || return; aok_confirm "Back up and copy repository configuration from $src to $dst?" || return; mkdir -p "$dst/etc/apt" "$V80_STATE_DIR/backups"; stamp=$(date +%Y%m%d-%H%M%S); [ -d "$dst/etc/apt" ] && tar -czf "$V80_STATE_DIR/backups/apt-$stamp.tar.gz" -C "$dst/etc" apt 2>/dev/null || true; [ -d "$src/etc/apt" ] && cp -a "$src/etc/apt/." "$dst/etc/apt/"; [ -d "$src/etc/apk" ] && { mkdir -p "$dst/etc/apk"; cp -a "$src/etc/apk/." "$dst/etc/apk/"; }; ui_msg Workspace 'Repository synchronization completed.'; }
multi_rootfs_menu(){ while :; do c=$(ui_menu 'Multi-RootFS Workspace' 'Run safe operations across multiple registered RootFS instances.' health 'Health summary for all RootFS instances' packages 'Compare package inventories' diff 'Open advanced RootFS diff' repos 'Copy repository configuration with backup' registry 'Open RootFS registry') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in health) multi_rootfs_health;; packages) multi_rootfs_package_compare;; diff) advanced_rootfs_diff_menu_v72;; repos) multi_rootfs_repo_sync;; registry) rootfs_registry_browser;; esac; done; }

rootfs_deep_diff(){ a=$(rootfs_select_registered) || return; b=$(rootfs_select_registered) || return; out="$ROOTFS_REPORT_DIR/deep-diff-$(rootfs_id "$a")-$(rootfs_id "$b")-$(date +%Y%m%d-%H%M%S).txt"; { echo 'Advanced RootFS Diff'; echo "A: $a"; echo "B: $b"; for p in etc/passwd etc/group etc/os-release etc/hostname etc/resolv.conf; do echo; echo "[$p]"; diff -u "$a/$p" "$b/$p" 2>/dev/null || true; done; echo; echo '[repositories]'; diff -ru "$a/etc/apt" "$b/etc/apt" 2>/dev/null | head -500 || true; echo; echo '[services]'; diff -ru "$a/etc/init.d" "$b/etc/init.d" 2>/dev/null | head -500 || true; echo; echo '[configuration file list]'; (cd "$a" && find etc -type f -print 2>/dev/null | sort) >"$TMP_DIR/fa"; (cd "$b" && find etc -type f -print 2>/dev/null | sort) >"$TMP_DIR/fb"; diff -u "$TMP_DIR/fa" "$TMP_DIR/fb" 2>/dev/null || true; } >"$out"; ui_text 'Advanced RootFS Diff' "$(cat "$out")"; }

platform_monitor_report(){
  printf 'iSH-AOK Platform Monitor\n\nHost\n'
  printf '  Distribution: %s\n  Architecture: %s\n  Init: %s\n' "$DISTRO_ID" "$ARCH" "$INIT_SYSTEM"
  awk '/MemTotal|MemAvailable/{printf "  %s %s %s\n",$1,$2,$3}' /proc/meminfo 2>/dev/null
  df -h "$STATE_DIR" 2>/dev/null | sed 's/^/  /'
  printf '\nActive RootFS\n  %s\n' "$(active_rootfs)"
  printf '\nWorkflow runs\n'; find "$STATE_DIR/workflows/runs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | awk '{print "  Total: "$1}'
  printf '\nProjects\n'; rootfs_project_list | wc -l | awk '{print "  Total: "$1}'
}
platform_monitor_menu(){ while :; do c=$(ui_menu 'Platform Monitor' "$(platform_monitor_report)" refresh 'Refresh' workflows 'Workflow history' reports 'Reports browser' inventory 'System inventory') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in refresh) :;; workflows) workflow_history_menu;; reports) rootfs_reports_browser;; inventory) inventory_menu;; esac; done; }

plugin_repo_add(){ name=$(v80_safe_id "$(ui_input 'Plugin repository' 'Repository name' community)") || return; url=$(ui_input 'Plugin repository' 'Index URL or local file path' '') || return; [ -n "$name" ] && printf '%s\n' "$url" >"$V80_PLUGIN_REPOS_DIR/$name.repo"; }
plugin_repo_refresh_one(){ f=$1; src=$(cat "$f"); out="${f%.repo}.index"; case $src in http://*|https://*) have curl && curl -fsSL "$src" -o "$out" || { have wget && wget -qO "$out" "$src"; };; *) cp "$src" "$out";; esac; }
plugin_repo_refresh(){ for f in "$V80_PLUGIN_REPOS_DIR"/*.repo; do [ -f "$f" ] && plugin_repo_refresh_one "$f" || true; done; ui_msg 'Plugin repositories' 'Repository indexes refreshed.'; }
plugin_repo_search(){ q=$(ui_input 'Plugin repository search' 'Search term' '') || return; grep -iH -- "$q" "$V80_PLUGIN_REPOS_DIR"/*.index 2>/dev/null >"$TMP_DIR/plugin-repo-search" || true; ui_text 'Plugin repository results' "$(cat "$TMP_DIR/plugin-repo-search")"; }
plugin_repo_install(){ spec=$(ui_input 'Install repository plugin' 'Archive URL or local archive path' '') || return; [ -n "$spec" ] || return; tmp="$TMP_DIR/plugin-package"; case $spec in http://*|https://*) have curl && curl -fsSL "$spec" -o "$tmp" || wget -qO "$tmp" "$spec";; *) cp "$spec" "$tmp";; esac || return; sdk_install_archive "$tmp"; }
plugin_repository_menu(){ while :; do c=$(ui_menu 'Plugin Repository' 'Manage optional extension indexes and verified local installs.' add 'Add repository index' refresh 'Refresh indexes' search 'Search indexes' install 'Install plugin archive' sdk 'Open Module and Plugin SDK') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in add) plugin_repo_add;; refresh) plugin_repo_refresh;; search) plugin_repo_search;; install) plugin_repo_install;; sdk) sdk_center;; esac; done; }

docs_generate(){ fmt=$1; out="$V80_DOCS_DIR/platform-$(date +%Y%m%d-%H%M%S).$fmt"; case $fmt in json) { printf '{\n  "version":"%s",\n  "actions":[' "$VERSION"; awk -F '\t' 'BEGIN{first=1}{gsub(/"/,"\\\""); if(!first)printf ","; printf "\n    {\"id\":\"%s\",\"title\":\"%s\",\"category\":\"%s\"}",$1,$2,$3; first=0}END{print "\n  ]\n}"}' "$V73_ACTIONS_FILE"; } >"$out";; *) { echo "# $PROGRAM $VERSION"; echo; echo '## Registered actions'; awk -F '\t' '{printf "- `%s` — **%s** (%s): %s\n",$1,$2,$3,$5}' "$V73_ACTIONS_FILE"; echo; echo '## Modules'; sdk_module_report; echo; echo '## Workflows'; workflow_report; } >"$out";; esac; ui_msg Documentation "$out"; }
documentation_generator_menu(){ while :; do c=$(ui_menu 'Documentation Generator' 'Generate documentation from actions, modules and workflows.' markdown 'Generate Markdown' json 'Generate JSON' browse 'Browse generated documents') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in markdown) docs_generate md;; json) docs_generate json;; browse) ui_text Documentation "$(find "$V80_DOCS_DIR" -maxdepth 1 -type f -print 2>/dev/null)";; esac; done; }

workflow_visualize(){ id=$(workflow_select_pipeline) || return; f=$(workflow_pipeline_file "$id"); out="$V80_DOCS_DIR/workflow-$id-graph.txt"; { echo "$id"; echo; awk -F '\t' 'BEGIN{n=0} /^#/||NF<2{next} {if(n++)print "   |"; print "   v"; print "[ "$2" ]"}' "$f"; } >"$out"; ui_text 'Workflow graph' "$(cat "$out")"; }
workflow_visualizer_menu(){ while :; do c=$(ui_menu 'Workflow Visualizer' 'Review pipeline structure before execution.' graph 'Render workflow graph' report 'Workflow report' engine 'Open Workflow Engine') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in graph) workflow_visualize;; report) ui_text Workflows "$(workflow_report)";; engine) workflow_engine_menu;; esac; done; }

remote_rootfs_menu(){ ui_text 'Remote RootFS support' 'Remote management is optional and conservative in v8.0. Use SSH to run the same installed ish-aok-config version remotely:\n\nssh HOST ish-aok-config --workspace-report\nssh HOST ish-aok-config --workflow health_audit\n\nSnapshot and artifact transfer can use scp or rsync. Credentials and host keys are never stored by this module.'; }

platform_v80_menu(){ while :; do c=$(ui_menu 'v8 RootFS Platform' "Active: $(active_rootfs)" projects 'RootFS Projects' recipes 'Build Recipes' workspace 'Multi-RootFS Workspace' diff 'Advanced Diff Engine' monitor 'Resource and workflow monitoring' remote 'Remote RootFS guidance' plugins 'Plugin Repository' docs 'Documentation Generator' visualizer 'Workflow Visualizer') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in projects) rootfs_projects_menu;; recipes) build_recipes_menu;; workspace) multi_rootfs_menu;; diff) rootfs_deep_diff;; monitor) platform_monitor_menu;; remote) remote_rootfs_menu;; plugins) plugin_repository_menu;; docs) documentation_generator_menu;; visualizer) workflow_visualizer_menu;; esac; done; }
platform_v80_report(){ echo "$PROGRAM $VERSION — RootFS Platform"; echo; echo 'Projects:'; rootfs_project_list; echo; echo 'Recipes:'; build_recipe_list; echo; platform_monitor_report; }

# v8.1 Project Operations
V81_REMOTE_DIR=$V80_STATE_DIR/remotes
mkdir -p "$V81_REMOTE_DIR" 2>/dev/null || true

rootfs_project_activate(){
  id=$(rootfs_project_select) || return
  f=$(v80_project_file "$id"); r=$(v80_conf_get "$f" rootfs)
  [ -d "$r" ] || { ui_msg Projects "RootFS path is unavailable: $r"; return 1; }
  set_active_rootfs "$r"
  v80_conf_set "$f" last_used "$(date '+%Y-%m-%dT%H:%M:%S')"
  activity_add project "Activated project $id"
  ui_msg Projects "Active project: $(v80_conf_get "$f" name)\nRootFS: $r"
}

rootfs_project_delete(){
  id=$(rootfs_project_select) || return
  d="$V80_PROJECTS_DIR/$id"; f="$d/project.conf"
  aok_confirm "Delete project metadata for $(v80_conf_get "$f" name)?\n\nThe RootFS itself will not be deleted." || return
  rm -rf "$d"
  activity_add project "Deleted project metadata $id"
  ui_msg Projects 'Project metadata removed. The RootFS was not deleted.'
}

rootfs_project_import(){
  src=$(ui_input 'Import RootFS project' 'Project archive or directory' '') || return
  [ -e "$src" ] || { ui_msg Projects 'Source does not exist.'; return 1; }
  tmp="$TMP_DIR/project-import-$$"; rm -rf "$tmp"; mkdir -p "$tmp"
  case $src in
    *.tar.gz|*.tgz) tar -xzf "$src" -C "$tmp" || return 1;;
    *.tar.xz|*.txz) tar -xJf "$src" -C "$tmp" || return 1;;
    *.tar) tar -xf "$src" -C "$tmp" || return 1;;
    *) cp -a "$src" "$tmp/" || return 1;;
  esac
  conf=$(find "$tmp" -name project.conf -type f 2>/dev/null | head -n 1)
  [ -f "$conf" ] || { ui_msg Projects 'No project.conf was found.'; return 1; }
  id=$(v80_safe_id "$(v80_conf_get "$conf" id)"); [ -n "$id" ] || return 1
  dst="$V80_PROJECTS_DIR/$id"
  [ ! -e "$dst" ] || { aok_confirm "Replace existing project $id?" || return; rm -rf "$dst"; }
  cp -a "$(dirname "$conf")" "$dst"
  ui_msg Projects "Imported project: $id"
}

build_recipe_validate_file(){
  f=$1; missing=''
  for k in id distro release arch bootstrap packages; do
    [ -n "$(v80_conf_get "$f" "$k")" ] || missing="$missing $k"
  done
  [ -z "$missing" ] || { printf 'Missing fields:%s\n' "$missing"; return 1; }
  case $(v80_conf_get "$f" bootstrap) in debootstrap|mmdebstrap|apk|pacstrap|dnf|xbps|stage3|custom) :;; *) printf 'Warning: unknown bootstrap method: %s\n' "$(v80_conf_get "$f" bootstrap)";; esac
  printf 'Recipe is structurally valid.\n'
}

build_recipe_validate(){ id=$(build_recipe_select) || return; f="$V80_RECIPES_DIR/$id.recipe"; ui_text 'Recipe validation' "$(build_recipe_validate_file "$f" 2>&1)"; }
build_recipe_import(){ src=$(ui_input 'Import build recipe' 'Recipe file path' '') || return; [ -f "$src" ] || { ui_msg Recipes 'Recipe file not found.'; return 1; }; id=$(v80_safe_id "$(v80_conf_get "$src" id)"); [ -n "$id" ] || { ui_msg Recipes 'Recipe ID is missing.'; return 1; }; build_recipe_validate_file "$src" >/dev/null 2>&1 || { ui_text 'Recipe validation' "$(build_recipe_validate_file "$src" 2>&1)"; return 1; }; cp "$src" "$V80_RECIPES_DIR/$id.recipe"; ui_msg Recipes "Imported: $id"; }

multi_rootfs_inventory_report(){
  out="$ROOTFS_REPORT_DIR/multi-rootfs-inventory-$(date +%Y%m%d-%H%M%S).tsv"
  printf 'path\tdistro\tarch\tinit\tpackage_manager\thealth\n' >"$out"
  old=$(active_rootfs)
  rootfs_registry_paths | while IFS= read -r r; do
    [ -d "$r" ] || continue
    set_active_rootfs "$r"
    h=$(rootfs_health_report 2>/dev/null || true)
    score=$(sed -n 's/.*Health score:[[:space:]]*//p' "$h" | head -n 1)
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$r" "$(aok_root_os "$r")" "$(aok_root_arch "$r")" "$(rootfs_detect_init "$r")" "$(rootfs_detect_package_manager "$r")" "${score:-unknown}" >>"$out"
  done
  set_active_rootfs "$old"
  ui_text 'Multi-RootFS inventory' "$(cat "$out")"
}

plugin_repo_install_verified(){
  spec=$(ui_input 'Install repository plugin' 'Archive URL or local archive path' '') || return
  [ -n "$spec" ] || return
  expected=$(ui_input 'Plugin checksum' 'Expected SHA-256 (optional)' '') || return
  tmp="$TMP_DIR/plugin-package-$$"
  case $spec in http://*|https://*) have curl && curl -fsSL "$spec" -o "$tmp" || { have wget && wget -qO "$tmp" "$spec"; };; *) cp "$spec" "$tmp";; esac || return
  if [ -n "$expected" ]; then
    have sha256sum || { ui_msg Plugins 'sha256sum is required for verification.'; return 1; }
    actual=$(sha256sum "$tmp" | awk '{print $1}')
    [ "$actual" = "$expected" ] || { ui_msg Plugins "Checksum mismatch.\nExpected: $expected\nActual:   $actual"; return 1; }
  fi
  sdk_install_archive "$tmp"
}

remote_profile_list(){ for f in "$V81_REMOTE_DIR"/*.conf; do [ -f "$f" ] || continue; printf '%s\t%s\t%s\n' "$(v80_conf_get "$f" id)" "$(v80_conf_get "$f" host)" "$(v80_conf_get "$f" user)"; done; }
remote_profile_select(){ set --; while IFS="$(printf '\t')" read -r id host user; do [ -n "$id" ] && set -- "$@" "$id" "$user@$host"; done <<EOF_REMOTES
$(remote_profile_list)
EOF_REMOTES
  [ "$#" -gt 0 ] || return 1; ui_menu 'Remote profiles' 'Select a remote host.' "$@";
}
remote_profile_add(){ id=$(v80_safe_id "$(ui_input 'Remote profile' 'Profile ID' devuan-host)") || return; host=$(ui_input 'Remote profile' 'Hostname or IP address' '') || return; user=$(ui_input 'Remote profile' 'SSH user' root) || return; port=$(ui_input 'Remote profile' 'SSH port' 22) || return; [ -n "$id" ] && [ -n "$host" ] || return 1; printf 'id=%s\nhost=%s\nuser=%s\nport=%s\n' "$id" "$host" "$user" "$port" >"$V81_REMOTE_DIR/$id.conf"; }
remote_profile_report(){ id=$(remote_profile_select) || return; f="$V81_REMOTE_DIR/$id.conf"; host=$(v80_conf_get "$f" host); user=$(v80_conf_get "$f" user); port=$(v80_conf_get "$f" port); run_capture 'Remote workspace report' ssh -p "$port" "$user@$host" ish-aok-config --workspace-report; }
remote_profile_health(){ id=$(remote_profile_select) || return; f="$V81_REMOTE_DIR/$id.conf"; host=$(v80_conf_get "$f" host); user=$(v80_conf_get "$f" user); port=$(v80_conf_get "$f" port); aok_confirm "Run the health workflow on $user@$host?" || return; run_capture 'Remote health workflow' ssh -p "$port" "$user@$host" ish-aok-config --workflow health_audit; }
remote_profile_remove(){ id=$(remote_profile_select) || return; aok_confirm "Remove remote profile $id?" && rm -f "$V81_REMOTE_DIR/$id.conf"; }
remote_rootfs_menu(){ while :; do c=$(ui_menu 'Remote RootFS' 'Manage optional SSH profiles. Credentials and private keys are never stored.' add 'Add remote profile' list 'List profiles' report 'Fetch remote workspace report' health 'Run remote health workflow' remove 'Remove profile' guide 'Show manual command examples') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in add) remote_profile_add;; list) ui_text 'Remote profiles' "$(remote_profile_list)";; report) remote_profile_report;; health) remote_profile_health;; remove) remote_profile_remove;; guide) ui_text 'Remote RootFS guidance' 'Install the same ish-aok-config release remotely, configure SSH keys, then use workspace reports and workflows through SSH. Host-key checking follows your normal SSH configuration.';; esac; done; }

rootfs_projects_menu(){ while :; do c=$(ui_menu 'RootFS Projects' 'Group RootFS metadata, snapshots, overlays, reports, workflows and artifacts.' create 'Create project from active RootFS' activate 'Activate project RootFS' open 'View project details' import 'Import project bundle' export 'Export project bundle' delete 'Delete project metadata' report 'Project registry report') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in create) rootfs_project_create;; activate) rootfs_project_activate;; open) rootfs_project_open;; import) rootfs_project_import;; export) rootfs_project_export;; delete) rootfs_project_delete;; report) ui_text Projects "$(rootfs_project_list)";; esac; done; }
build_recipes_menu(){ while :; do c=$(ui_menu 'Build Recipes' 'Create reusable, version-control-friendly RootFS build plans.' create 'Create recipe' browse 'Browse recipes' validate 'Validate recipe' run 'Review and run recipe' import 'Import recipe' export 'Export recipe') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in create) build_recipe_create;; browse) id=$(build_recipe_select) || continue; ui_text Recipe "$(cat "$V80_RECIPES_DIR/$id.recipe")";; validate) build_recipe_validate;; run) build_recipe_run;; import) build_recipe_import;; export) build_recipe_export;; esac; done; }
multi_rootfs_menu(){ while :; do c=$(ui_menu 'Multi-RootFS Workspace' 'Run safe operations across multiple registered RootFS instances.' health 'Health summary for all RootFS instances' inventory 'Generate consolidated inventory' packages 'Compare package inventories' diff 'Open advanced RootFS diff' repos 'Copy repository configuration with backup' registry 'Open RootFS registry') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in health) multi_rootfs_health;; inventory) multi_rootfs_inventory_report;; packages) multi_rootfs_package_compare;; diff) advanced_rootfs_diff_menu_v72;; repos) multi_rootfs_repo_sync;; registry) rootfs_registry_browser;; esac; done; }
plugin_repository_menu(){ while :; do c=$(ui_menu 'Plugin Repository' 'Manage optional extension indexes and checksum-verified installs.' add 'Add repository index' refresh 'Refresh indexes' search 'Search indexes' install 'Install and optionally verify plugin archive' sdk 'Open Module and Plugin SDK') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in add) plugin_repo_add;; refresh) plugin_repo_refresh;; search) plugin_repo_search;; install) plugin_repo_install_verified;; sdk) sdk_center;; esac; done; }
platform_v80_report(){ echo "$PROGRAM $VERSION — RootFS Platform Project Operations"; echo; echo 'Projects:'; rootfs_project_list; echo; echo 'Recipes:'; build_recipe_list; echo; echo 'Remote profiles:'; remote_profile_list; echo; platform_monitor_report; }
