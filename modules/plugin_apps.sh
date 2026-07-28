#!/bin/sh

plugin_selection_has() {
    list=$1
    needle=$2
    for item in $list; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

plugin_managed_block_body() {
    file=$1
    block=$2
    [ -f "$file" ] || return 0
    start="# >>> ish-aok-config: $block >>>"
    end="# <<< ish-aok-config: $block <<<"
    awk -v start="$start" -v end="$end" '
        $0 == start { inside=1; next }
        $0 == end { inside=0; exit }
        inside { print }
    ' "$file" 2>/dev/null
}

plugin_shell_enabled_list() {
    file=$1
    block=$2
    plugin_managed_block_body "$file" "$block" |
        sed -n 's/.*plugins=(\([^)]*\)).*/\1/p; s/.*BASH_IT_PLUGINS="\([^"]*\)".*/\1/p' |
        tr '\n' ' '
}

plugin_repo_enabled() {
    file=$1
    block=$2
    repo=$3
    plugin_managed_block_body "$file" "$block" | grep -Fq "$repo"
}

plugin_options_state_checklist() {
    app=$1
    title=$2
    enabled=$3
    set --
    oldifs=$IFS
    IFS='|'
    while read -r id desc; do
        [ -n "$id" ] || continue
        state=off
        plugin_selection_has "$enabled" "$id" && state=on
        set -- "$@" "$id" "$desc" "$state"
    done <<EOF_LIST
$(plugin_options_list "$app")
EOF_LIST
    IFS=$oldifs
    [ $# -gt 0 ] || return 1
    ui_checklist "$title" 'Available plugins are listed below. Checked entries are enabled. Space toggles; Enter applies the complete selection.' "$@"
}

plugin_repo_state_checklist() {
    app=$1
    title=$2
    file=$3
    block=$4
    set --
    oldifs=$IFS
    IFS='|'
    while read -r id desc; do
        [ -n "$id" ] || continue
        state=off
        plugin_repo_enabled "$file" "$block" "$id" && state=on
        set -- "$@" "$id" "$desc" "$state"
    done <<EOF_LIST
$(plugin_options_list "$app")
EOF_LIST
    IFS=$oldifs
    [ $# -gt 0 ] || return 1
    ui_checklist "$title" 'Available plugins are listed below. Checked entries are enabled. Space toggles; Enter applies the complete selection.' "$@"
}

plugin_apply_repo_block() {
    app=$1
    file=$2
    block=$3
    prefix=$4
    suffix=$5
    selected=$6
    body=''
    oldifs=$IFS
    IFS='|'
    while read -r id desc; do
        [ -n "$id" ] || continue
        if plugin_selection_has "$selected" "$id"; then
            [ -n "$body" ] && body="$body
"
            body="$body$prefix$id$suffix"
        fi
    done <<EOF_LIST
$(plugin_options_list "$app")
EOF_LIST
    IFS=$oldifs
    if [ -n "$body" ]; then
        replace_block "$file" "$block" "$body"
    else
        remove_managed_block "$file" "$block"
    fi
}

plugin_omb_manage() {
    while :; do
        c=$(ui_menu 'Oh My Bash manager' 'Install the framework and manage plugins from selectable lists.' \
            framework 'Install/update Oh My Bash framework' \
            enable 'Enable or disable available plugins' \
            theme 'Select theme' \
            preset 'Apply recommended plugin preset' \
            remove 'Remove Oh My Bash framework') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
        case $c in
            framework) plugin_item_menu oh-my-bash ;;
            enable)
                current=$(plugin_shell_enabled_list "$CURRENT_HOME/.bashrc" oh-my-bash-plugins)
                sel=$(plugin_options_state_checklist omb_plugins 'Enable Oh My Bash plugins' "$current") || continue
                [ -n "$sel" ] && replace_block "$CURRENT_HOME/.bashrc" oh-my-bash-plugins "plugins=($sel)" || remove_managed_block "$CURRENT_HOME/.bashrc" oh-my-bash-plugins
                ;;
            theme)
                set --
                oldifs=$IFS; IFS='|'
                while read -r id desc; do [ -n "$id" ] && set -- "$@" "$id" "$desc"; done <<EOF_LIST
$(plugin_options_list omb_themes)
EOF_LIST
                IFS=$oldifs
                t=$(ui_menu 'Oh My Bash theme' 'Select an installed Oh My Bash theme.' "$@") || continue
                replace_block "$CURRENT_HOME/.bashrc" oh-my-bash-theme "OSH_THEME=\"$t\""
                ;;
            preset) replace_block "$CURRENT_HOME/.bashrc" oh-my-bash-plugins 'plugins=(git aliases alias-completion archive extract history path ssh sudo tmux)' ;;
            remove) plugin_remove oh-my-bash ;;
        esac
    done
}

plugin_omz_manage() {
    while :; do
        c=$(ui_menu 'Oh My Zsh manager' 'Install the framework and manage plugins from selectable lists.' \
            framework 'Install/update Oh My Zsh framework' \
            enable 'Enable or disable available plugins' \
            theme 'Select theme' \
            preset 'Apply recommended plugin preset' \
            extras 'Install selectable external Zsh plugins' \
            remove 'Remove Oh My Zsh framework') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
        case $c in
            framework) plugin_item_menu oh-my-zsh ;;
            enable)
                current=$(plugin_shell_enabled_list "$CURRENT_HOME/.zshrc" oh-my-zsh-plugins)
                sel=$(plugin_options_state_checklist omz_plugins 'Enable Oh My Zsh plugins' "$current") || continue
                [ -n "$sel" ] && replace_block "$CURRENT_HOME/.zshrc" oh-my-zsh-plugins "plugins=($sel)" || remove_managed_block "$CURRENT_HOME/.zshrc" oh-my-zsh-plugins
                ;;
            theme)
                set --
                oldifs=$IFS; IFS='|'
                while read -r id desc; do [ -n "$id" ] && set -- "$@" "$id" "$desc"; done <<EOF_LIST
$(plugin_options_list omz_themes)
EOF_LIST
                IFS=$oldifs
                t=$(ui_menu 'Oh My Zsh theme' 'Select an Oh My Zsh theme.' "$@") || continue
                replace_block "$CURRENT_HOME/.zshrc" oh-my-zsh-theme "ZSH_THEME=\"$t\""
                ;;
            preset) replace_block "$CURRENT_HOME/.zshrc" oh-my-zsh-plugins 'plugins=(git sudo history colored-man-pages command-not-found extract fzf zoxide ssh-agent tmux)' ;;
            extras)
                current=''
                for x in zsh-autosuggestions zsh-syntax-highlighting fzf-tab; do plugin_installed "$x" && current="$current $x"; done
                sel=$(ui_checklist 'External Zsh plugins' 'Checked entries will be installed and enabled. Unchecked managed entries will be disabled but retained.' \
                    zsh-autosuggestions 'Fish-like autosuggestions' "$(plugin_selection_has "$current" zsh-autosuggestions && echo on || echo off)" \
                    zsh-syntax-highlighting 'Command syntax highlighting' "$(plugin_selection_has "$current" zsh-syntax-highlighting && echo on || echo off)" \
                    fzf-tab 'fzf-powered completion menu' "$(plugin_selection_has "$current" fzf-tab && echo on || echo off)") || continue
                for x in zsh-autosuggestions zsh-syntax-highlighting fzf-tab; do
                    if plugin_selection_has "$sel" "$x"; then run_capture "Install and enable $x" plugin_install_git "$x" || true
                    else plugin_disable "$x"
                    fi
                done
                ;;
            remove) plugin_remove oh-my-zsh ;;
        esac
    done
}

plugin_bashit_manage() {
    while :; do
        c=$(ui_menu 'Bash-it manager' 'Install Bash-it and manage components from an available-plugin list.' \
            framework 'Install/update Bash-it framework' \
            enable 'Enable or disable available components' \
            preset 'Apply developer preset' \
            remove 'Remove Bash-it') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
        case $c in
            framework) plugin_item_menu bash-it ;;
            enable)
                current=$(plugin_shell_enabled_list "$CURRENT_HOME/.bashrc" bash-it-selected)
                sel=$(plugin_options_state_checklist bashit_plugins 'Enable Bash-it components' "$current") || continue
                [ -n "$sel" ] && replace_block "$CURRENT_HOME/.bashrc" bash-it-selected "export BASH_IT_PLUGINS=\"$sel\"" || remove_managed_block "$CURRENT_HOME/.bashrc" bash-it-selected
                ;;
            preset) replace_block "$CURRENT_HOME/.bashrc" bash-it-selected 'export BASH_IT_PLUGINS="base alias-completion dirs extract fzf git history man projects ssh tmux zoxide"' ;;
            remove) plugin_remove bash-it ;;
        esac
    done
}

plugin_fish_manage() {
    while :; do
        c=$(ui_menu 'Fisher and Fish plugins' 'Install Fisher and manage available Fish plugins.' \
            framework 'Install/update Fisher' \
            enable 'Enable or disable available Fish plugins' \
            update 'Update all Fisher packages' \
            list 'List installed Fisher packages') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
        case $c in
            framework) run_capture 'Install Fisher' plugin_install_git fisher ;;
            enable)
                have fish || { ui_msg Fish 'Fish is not installed.'; continue; }
                current=$(fish -c 'fisher list' 2>/dev/null | tr '\n' ' ')
                sel=$(plugin_options_state_checklist fish_plugins 'Enable Fisher plugins' "$current") || continue
                oldifs=$IFS; IFS='|'
                while read -r p desc; do
                    [ -n "$p" ] || continue
                    if plugin_selection_has "$sel" "$p"; then
                        plugin_selection_has "$current" "$p" || run_capture "Install Fish plugin: $p" fish -c "fisher install $p" || true
                    elif plugin_selection_has "$current" "$p"; then
                        run_capture "Remove Fish plugin: $p" fish -c "fisher remove $p" || true
                    fi
                done <<EOF_LIST
$(plugin_options_list fish_plugins)
EOF_LIST
                IFS=$oldifs
                ;;
            update) run_capture 'Update Fisher packages' fish -c 'fisher update' ;;
            list) ui_text Fisher "$(fish -c 'fisher list' 2>&1)" ;;
        esac
    done
}

plugin_vim_manage() {
    while :; do
        c=$(ui_menu 'Vim plugin manager' 'Install vim-plug and manage available plugins.' \
            framework 'Install/update vim-plug' \
            enable 'Enable or disable available Vim plugins' \
            install 'Install configured plugins' \
            update 'Update configured plugins' \
            clean 'Remove unused plugins') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
        case $c in
            framework) run_capture 'Install vim-plug' plugin_install_git vim-plug ;;
            enable)
                sel=$(plugin_repo_state_checklist vim_plugins 'Enable Vim plugins' "$CURRENT_HOME/.vimrc" vim-plug) || continue
                plugin_apply_repo_block vim_plugins "$CURRENT_HOME/.vimrc" vim-plug "Plug '" "'" "$sel"
                ;;
            install) run_capture 'Install Vim plugins' vim +PlugInstall +qall ;;
            update) run_capture 'Update Vim plugins' vim +PlugUpdate +qall ;;
            clean) run_capture 'Clean Vim plugins' vim +PlugClean +qall ;;
        esac
    done
}

plugin_nvim_manage() {
    while :; do
        c=$(ui_menu 'Neovim plugin manager' 'Install lazy.nvim and manage available plugins.' \
            framework 'Install/update lazy.nvim' \
            enable 'Enable or disable available Neovim plugins' \
            sync 'Synchronize configured plugins' \
            health 'Run Neovim health check') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
        case $c in
            framework) run_capture 'Install lazy.nvim' plugin_install_git lazy-nvim ;;
            enable)
                file=$CURRENT_HOME/.config/nvim/lua/ish_aok_plugins.lua
                sel=$(plugin_repo_state_checklist nvim_plugins 'Enable Neovim plugins' "$file" nvim-lazy) || continue
                plugin_apply_repo_block nvim_plugins "$file" nvim-lazy "  { '" "' }," "$sel"
                ;;
            sync) run_capture 'Synchronize Neovim plugins' nvim --headless '+Lazy! sync' +qa ;;
            health) run_capture 'Neovim health check' nvim --headless '+checkhealth' +qa ;;
        esac
    done
}

plugin_tmux_manage() {
    while :; do
        c=$(ui_menu 'Tmux plugin manager' 'Install TPM and manage available plugins.' \
            framework 'Install/update TPM' \
            enable 'Enable or disable available Tmux plugins' \
            install 'Install configured plugins' \
            update 'Update configured plugins' \
            clean 'Remove unused plugins') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
        case $c in
            framework) run_capture 'Install TPM' plugin_install_git tpm ;;
            enable)
                sel=$(plugin_repo_state_checklist tmux_plugins 'Enable Tmux plugins' "$CURRENT_HOME/.tmux.conf" tmux-plugins) || continue
                plugin_apply_repo_block tmux_plugins "$CURRENT_HOME/.tmux.conf" tmux-plugins "set -g @plugin '" "'" "$sel"
                replace_block "$CURRENT_HOME/.tmux.conf" tpm-init 'run-shell ~/.tmux/plugins/tpm/tpm'
                ;;
            install) run_capture 'Install Tmux plugins' "$CURRENT_HOME/.tmux/plugins/tpm/bin/install_plugins" ;;
            update) run_capture 'Update Tmux plugins' "$CURRENT_HOME/.tmux/plugins/tpm/bin/update_plugins" all ;;
            clean) run_capture 'Clean Tmux plugins' "$CURRENT_HOME/.tmux/plugins/tpm/bin/clean_plugins" ;;
        esac
    done
}

plugin_nnn_current() {
    plugin_managed_block_body "$CURRENT_HOME/.profile" nnn-plugins |
        sed -n "s/.*NNN_PLUG=['\"]\([^'\"]*\)['\"].*/\1/p" |
        tr ';' '\n' | sed 's/^[^:]*://' | tr '\n' ' '
}

plugin_nnn_manage() {
    plugin_installed nnn-plugins || run_capture 'Install nnn plugins' plugin_install_git nnn-plugins || return
    while :; do
        c=$(ui_menu 'nnn plugin manager' 'Manage official nnn plugins from an available-plugin checklist.' \
            enable 'Enable or disable available nnn plugins' \
            preset 'Apply recommended navigation preset' \
            list 'List installed plugin files' \
            update 'Update official plugin collection' \
            remove 'Remove managed plugin collection') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
        case $c in
            enable)
                current=$(plugin_nnn_current)
                sel=$(plugin_options_state_checklist nnn_plugins 'Enable nnn plugins' "$current") || continue
                keys='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
                out=''; i=1
                for p in $sel; do
                    key=$(printf '%s' "$keys" | cut -c "$i")
                    [ -n "$key" ] || key=';'
                    [ -n "$out" ] && out="$out;"
                    out="$out$key:$p"
                    i=$((i+1))
                done
                [ -n "$out" ] && replace_block "$CURRENT_HOME/.profile" nnn-plugins "export NNN_PLUG='$out'" || remove_managed_block "$CURRENT_HOME/.profile" nnn-plugins
                ;;
            preset) replace_block "$CURRENT_HOME/.profile" nnn-plugins "export NNN_PLUG='p:preview-tui;o:fzopen;d:dupes;r:renamer;x:extract;z:zoxide;c:clipboard-copier;m:nmount;t:trash-cli'" ;;
            list) ui_text 'nnn plugins' "$(find "$CURRENT_HOME/.config/nnn/plugins" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort)" ;;
            update) run_capture 'Update nnn plugins' plugin_update nnn-plugins; plugin_post_install nnn-plugins ;;
            remove) plugin_remove nnn-plugins ;;
        esac
    done
}

plugin_micro_installed() {
    micro -plugin list 2>/dev/null | sed -n 's/^[[:space:]]*\([^[:space:]]*\).*/\1/p' | tr '\n' ' '
}

plugin_micro_manage() {
    while :; do
        c=$(ui_menu 'Micro plugin manager' 'Manage curated Micro plugins from an available-plugin checklist.' \
            enable 'Enable or disable available Micro plugins' \
            update 'Update all plugins' \
            list 'List installed plugins') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
        case $c in
            enable)
                have micro || { ui_msg Micro 'Micro is not installed.'; continue; }
                current=$(plugin_micro_installed)
                sel=$(plugin_options_state_checklist micro_plugins 'Enable Micro plugins' "$current") || continue
                oldifs=$IFS; IFS='|'
                while read -r p desc; do
                    [ -n "$p" ] || continue
                    if plugin_selection_has "$sel" "$p"; then
                        plugin_selection_has "$current" "$p" || run_capture "Install Micro plugin: $p" micro -plugin install "$p" || true
                    elif plugin_selection_has "$current" "$p"; then
                        run_capture "Remove Micro plugin: $p" micro -plugin remove "$p" || true
                    fi
                done <<EOF_LIST
$(plugin_options_list micro_plugins)
EOF_LIST
                IFS=$oldifs
                ;;
            update) run_capture 'Update Micro plugins' micro -plugin update ;;
            list) ui_text Micro "$(micro -plugin list 2>&1)" ;;
        esac
    done
}

plugin_lf_manage() {
    file=$CURRENT_HOME/.config/lf/lfrc
    mkdir -p "$CURRENT_HOME/.config/lf"
    current=$(plugin_managed_block_body "$file" lf-integrations | sed -n 's/^# enabled integration: //p' | tr '\n' ' ')
    sel=$(plugin_options_state_checklist lf_tools 'Enable lf integrations' "$current") || return
    body=''
    for p in $sel; do body="$body# enabled integration: $p
"; done
    [ -n "$body" ] && replace_block "$file" lf-integrations "$body" || remove_managed_block "$file" lf-integrations
}

plugin_application_menu() {
    while :; do
        c=$(ui_menu 'Application plugin managers' 'Choose a project or framework. Each manager lists available plugins and preselects enabled entries.' \
            omb 'Oh My Bash themes and plugins' \
            omz 'Oh My Zsh themes and plugins' \
            bashit 'Bash-it components' \
            fish 'Fisher and Fish plugins' \
            vim 'Vim and vim-plug plugins' \
            nvim 'Neovim and lazy.nvim plugins' \
            tmux 'Tmux Plugin Manager plugins' \
            nnn 'nnn official plugins' \
            micro 'Micro plugins' \
            lf 'lf integration helpers') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
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
        esac
    done
}
