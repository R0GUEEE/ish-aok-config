#!/bin/sh
plugin_manager_menu(){ filter=${1:-all}; while :; do c=$(ui_menu 'Plugin and framework manager' 'Install, enable, update, disable, and remove supported plugin systems. Manifests are stored in the user state directory.' apps 'Application plugin managers' catalog 'Browse framework catalog' installed 'Installed plugin systems' add 'Add custom Git plugin' update 'Update all installed plugins' configure 'Configure plugin entries' report 'Export plugin report') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in apps) plugin_application_menu;; catalog) plugin_catalog_menu "$filter";; installed) plugin_installed_menu;; add) plugin_custom_git;; update) run_capture 'Plugin updates' plugin_update_all;; configure) plugin_configuration_menu;; report) plugin_report;; esac; done; }
plugin_catalog_menu(){ filter=$1; set --; oldifs=$IFS; IFS='|'; while read -r id tool name; do [ -n "$id" ] || continue; if [ "$filter" = shell ]; then case $tool in bash|zsh|fish) :;; *) continue;; esac; fi; state=available; plugin_installed "$id" && state=installed; set -- "$@" "$id" "[$tool/$state] $name"; done <<EOF2
$(plugin_list_catalog)
EOF2
IFS=$oldifs; [ $# -gt 0 ] || { ui_msg Plugins 'No matching catalog entries.'; return; }; id=$(ui_menu 'Plugin catalog' 'Select a plugin framework or manager.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; plugin_item_menu "$id"; }
plugin_item_menu(){ id=$1; name=$(plugin_get_field "$id" name); while :; do c=$(ui_menu "$name" "Tool: $(plugin_get_field "$id" tool)\nRepository: $(plugin_get_field "$id" url)" install 'Install and enable' enable 'Enable configuration' disable 'Disable configuration only' update 'Update from repository' remove 'Remove installation and configuration' info 'Show catalog metadata') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in install) run_capture "$name install" plugin_install_git "$id";; enable) plugin_enable "$id"; ui_msg Plugins Enabled;; disable) plugin_disable "$id"; ui_msg Plugins Disabled;; update) run_capture "$name update" plugin_update "$id";; remove) ui_yesno Plugins "Remove $name?" && plugin_remove "$id";; info) ui_text "$name" "$(cat "$(plugin_catalog_file "$id")")";; esac; done; }
plugin_installed_menu(){ set --; for f in "$PLUGIN_MANIFEST_DIR"/*.manifest; do [ -f "$f" ] || continue; id=${f##*/}; id=${id%.manifest}; set -- "$@" "$id" "$(plugin_get_field "$id" name)"; done; [ $# -gt 0 ] || { ui_msg Plugins 'No managed plugin systems are installed.'; return; }; id=$(ui_menu 'Installed plugins' 'Select an installation.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; plugin_item_menu "$id"; }
plugin_custom_git(){ id=$(ui_input Plugin 'Unique plugin ID:' custom-plugin) || return; url=$(ui_input Plugin 'Git repository URL:' '') || return; dest=$(ui_input Plugin 'Install directory:' "$PLUGIN_DATA_DIR/$id") || return; tool=$(ui_input Plugin 'Associated tool:' generic) || return; cat >"$USER_PLUGIN_CATALOG/$id.plugin" <<EOF2
name=$id
tool=$tool
url=$url
dest=$dest
adapter=generic
EOF2
run_capture Plugin plugin_install_git "$id"; }
plugin_configuration_menu(){
    c=$(ui_menu 'Plugin configuration' 'Choose an application. Available plugins are presented in selectable lists; manual entry is reserved for custom Git plugins.' \
        omb 'Oh My Bash plugin checklist' \
        omz 'Oh My Zsh plugin checklist' \
        bashit 'Bash-it component checklist' \
        fish 'Fisher package checklist' \
        vim 'Vim plugin checklist' \
        nvim 'Neovim plugin checklist' \
        tmux 'Tmux plugin checklist' \
        nnn 'nnn plugin checklist' \
        micro 'Micro plugin checklist' \
        lf 'lf integration checklist' \
        custom 'Register a custom Git plugin') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
        omb) plugin_omb_manage ;;
        omz) plugin_omz_manage ;;
        bashit) plugin_bashit_manage ;;
        fish) plugin_fish_manage ;;
        vim) plugin_vim_manage ;;
        nvim) plugin_nvim_manage ;;
        tmux) plugin_tmux_manage ;;
        nnn) plugin_nnn_manage ;;
        micro) plugin_micro_manage ;;
        lf) plugin_lf_manage ;;
        custom) plugin_custom_git ;;
    esac
}

plugin_report(){ out=$REPORT_DIR/plugins.txt; { printf 'Plugin catalog\n==============\n'; plugin_list_catalog; printf '\nInstalled manifests\n===================\n'; for f in "$PLUGIN_MANIFEST_DIR"/*.manifest; do [ -f "$f" ] && { echo "--- $f"; cat "$f"; }; done; } >"$out"; ui_text 'Plugin report' "$(cat "$out")"; }
