#!/bin/sh
# Selectable configuration wizards for shells, terminals, editors and file managers.

wiz_has(){ printf '%s\n' "$1" | grep -Fxq "$2"; }
wiz_bool(){ f=$1; p=$2; grep -Eq "$p" "$f" 2>/dev/null && printf on || printf off; }
wiz_replace(){ f=$1; name=$2; body=$3; replace_block "$f" "$name" "$body"; ui_msg Saved "Updated $f. A backup was created when the file already existed."; }

bash_full_wizard(){
 f=$CURRENT_HOME/.bashrc; [ -e "$f" ] || write_file "$f" 644 ''
 opts=$(ui_checklist 'Bash configuration wizard' 'Select Bash behavior.' \
 histappend 'Append rather than overwrite history' on cmdhist 'Save multiline commands together' on lithist 'Preserve embedded newlines in history' off histverify 'Edit history expansion before running' on checkwinsize 'Update terminal dimensions' on autocd 'Type directory names to cd' off cdspell 'Correct minor cd spelling errors' off dirspell 'Correct directory spelling during completion' off globstar 'Recursive ** globbing' on nullglob 'Unmatched globs expand to nothing' off dotglob 'Include dotfiles in globs' off nocaseglob 'Case-insensitive globs' off nocasematch 'Case-insensitive [[ matching ]]' off extglob 'Extended glob patterns' on expandaliases 'Expand aliases in interactive shells' on sourcepath 'Search PATH when sourcing files' on huponexit 'Send HUP to jobs on login-shell exit' off checkjobs 'Warn about running jobs on exit' on histreedit 'Re-edit failed history substitution' on interactivecomments 'Allow comments interactively' on progcomp 'Programmable completion' on promptvars 'Expand variables in prompt' on shiftverbose 'Warn when shift exceeds arguments' off mailwarn 'Warn when mail already read' off forcefignore 'Enforce FIGNORE suffixes' off failglob 'Unmatched globs are errors' off lastpipe 'Run final pipeline command in current shell' off) || return
 hsize=$(ui_input Bash 'History entries kept in memory:' 10000) || return
 hfsize=$(ui_input Bash 'History entries saved to disk:' 20000) || return
 hc=$(ui_input Bash 'HISTCONTROL value:' 'ignoreboth:erasedups') || return
 prompt=$(ui_radiolist Bash 'Prompt style' simple 'user@host:path$' on twoline 'Two-line prompt' off minimal 'path$' off status 'Exit-status prompt' off) || return
 editmode=$(ui_radiolist Bash 'Readline editing mode' emacs Emacs on vi Vi off) || return
 body="# Bash options selected through TUI\nHISTCONTROL=$hc\nHISTSIZE=$hsize\nHISTFILESIZE=$hfsize\nset -o $editmode"
 for o in histappend cmdhist lithist histverify checkwinsize autocd cdspell dirspell globstar nullglob dotglob nocaseglob nocasematch extglob expandaliases sourcepath huponexit checkjobs histreedit interactivecomments progcomp promptvars shiftverbose mailwarn forcefignore failglob lastpipe; do wiz_has "$opts" "$o" && body="$body\nshopt -s $o" || body="$body\nshopt -u $o"; done
 case $prompt in simple) body="$body\nPS1='\\u@\\h:\\w\\$ '";; twoline) body="$body\nPS1='\\u@\\h [\\w]\\n\\$ '";; minimal) body="$body\nPS1='\\w\\$ '";; status) body="$body\nPS1='\\[\\e[31m\\]\\$?\\[\\e[0m\\] \\u@\\h:\\w\\$ '";; esac
 wiz_replace "$f" bash-wizard "$body"
}

zsh_full_wizard(){
 f=$CURRENT_HOME/.zshrc; [ -e "$f" ] || write_file "$f" 644 ''
 opts=$(ui_checklist 'Zsh configuration wizard' 'Select Zsh options.' \
 autocd 'Change directory by typing its name' on autopushd 'Push directories automatically' on pushdignoredups 'Avoid duplicate directory stack entries' on pushdminus 'Swap + and - stack meanings' off correct 'Command spelling correction' off correctall 'Argument spelling correction' off extendedglob 'Extended glob syntax' on globdots 'Include dotfiles in globs' off nomatch 'Error on unmatched glob' on numericglobsort 'Sort numeric filenames naturally' on interactivecomments 'Allow comments interactively' on completeinword 'Complete within words' on alwaystoend 'Move cursor to end after completion' on automenu 'Menu completion after repeated tab' on autolist 'List choices automatically' on listpacked 'Compact completion lists' on histignoredups 'Ignore consecutive duplicate history' on histignorespace 'Ignore commands beginning with space' on histreduceblanks 'Reduce extra blanks in history' on incappendhistory 'Append history immediately' on sharehistory 'Share history across sessions' on appendhistory 'Append history file' on extendedhistory 'Store timestamps and durations' on promptsubst 'Expand prompt substitutions' on transientrprompt 'Hide old right prompts' off beep 'Audible error bell' off) || return
 hsize=$(ui_input Zsh 'HISTSIZE:' 10000) || return; save=$(ui_input Zsh 'SAVEHIST:' 20000) || return
 keymap=$(ui_radiolist Zsh 'Key bindings' emacs Emacs on vi Vi off) || return
 prompt=$(ui_radiolist Zsh 'Prompt style' simple 'user@host:path%' on twoline 'Two-line prompt' off minimal 'path%' off) || return
 body="# Zsh options selected through TUI\nHISTFILE=\$HOME/.zsh_history\nHISTSIZE=$hsize\nSAVEHIST=$save\nbindkey -$keymap"
 for o in autocd autopushd pushdignoredups pushdminus correct correctall extendedglob globdots nomatch numericglobsort interactivecomments completeinword alwaystoend automenu autolist listpacked histignoredups histignorespace histreduceblanks incappendhistory sharehistory appendhistory extendedhistory promptsubst transientrprompt beep; do wiz_has "$opts" "$o" && body="$body\nsetopt ${o}" || body="$body\nunsetopt ${o}"; done
 body="$body\nautoload -Uz compinit && compinit"
 case $prompt in simple) body="$body\nPROMPT='%n@%m:%~%# '";; twoline) body="$body\nPROMPT='%n@%m [%~]\n%# '";; minimal) body="$body\nPROMPT='%~%# '";; esac
 wiz_replace "$f" zsh-wizard "$body"
}

fish_full_wizard(){
 f=$CURRENT_HOME/.config/fish/config.fish; mkdir -p "$(dirname "$f")"; [ -e "$f" ] || write_file "$f" 644 ''
 opts=$(ui_checklist 'Fish configuration wizard' 'Select Fish behavior.' greeting 'Show startup greeting' off vi 'Use Vi key bindings' off autosuggest 'Enable autosuggestions' on pagercolors 'Configure completion pager colors' on title 'Set terminal title' on abbreviations 'Install common abbreviations' on aliases 'Load ~/.aliases.fish' on direnv 'Enable direnv hook when installed' off zoxide 'Enable zoxide when installed' on starship 'Enable Starship when installed' on fzf 'Enable fzf integration when installed' on) || return
 body='# Fish options selected through TUI'
 wiz_has "$opts" greeting || body="$body\nset -g fish_greeting"
 wiz_has "$opts" vi && body="$body\nfish_vi_key_bindings" || body="$body\nfish_default_key_bindings"
 wiz_has "$opts" pagercolors && body="$body\nset -g fish_pager_color_prefix cyan --bold\nset -g fish_pager_color_completion normal\nset -g fish_pager_color_description yellow"
 wiz_has "$opts" title && body="$body\nfunction fish_title\n    prompt_pwd\nend"
 wiz_has "$opts" abbreviations && body="$body\nabbr -a ll 'ls -lah'\nabbr -a gs 'git status'\nabbr -a .. 'cd ..'"
 wiz_has "$opts" aliases && body="$body\ntest -f \$HOME/.aliases.fish; and source \$HOME/.aliases.fish"
 wiz_has "$opts" direnv && body="$body\ncommand -q direnv; and direnv hook fish | source"
 wiz_has "$opts" zoxide && body="$body\ncommand -q zoxide; and zoxide init fish | source"
 wiz_has "$opts" starship && body="$body\ncommand -q starship; and starship init fish | source"
 wiz_has "$opts" fzf && body="$body\ncommand -q fzf_configure_bindings; and fzf_configure_bindings"
 wiz_replace "$f" fish-wizard "$body"
}

ksh_full_wizard(){
 f=$CURRENT_HOME/.kshrc; [ -e "$f" ] || write_file "$f" 644 ''
 opts=$(ui_checklist 'Ksh configuration wizard' 'Select Korn shell options.' emacs 'Emacs editing mode' on vi 'Vi editing mode' off noclobber 'Prevent accidental redirection overwrite' on notify 'Report background jobs immediately' on trackall 'Track command locations' on allexport 'Export all assigned variables' off monitor 'Enable job control' on ignoreeof 'Require exit instead of Ctrl-D' off aliases 'Load ~/.aliases' on) || return
 body='# Ksh options selected through TUI'
 for o in emacs vi noclobber notify trackall allexport monitor ignoreeof; do wiz_has "$opts" "$o" && body="$body\nset -o $o" || true; done
 wiz_has "$opts" aliases && body="$body\n[ -f \"\$HOME/.aliases\" ] && . \"\$HOME/.aliases\""
 body="$body\nPS1='${USER:-user}@$(hostname 2>/dev/null):${PWD}\\$ '"
 wiz_replace "$f" ksh-wizard "$body"
}

shell_wizards_menu(){ while :; do c=$(ui_menu 'Shell configuration wizards' 'Configure shells with selectable options.' bash 'Complete Bash wizard' zsh 'Complete Zsh wizard' fish 'Complete Fish wizard' ash 'Ash wizard' ksh 'Ksh wizard' profile 'POSIX login profile wizard' inputrc 'Readline/inputrc wizard' starship 'Starship prompt wizard') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in bash) bash_full_wizard;; zsh) zsh_full_wizard;; fish) fish_full_wizard;; ash) ash_wizard "$CURRENT_HOME/.ashrc";; ksh) ksh_full_wizard;; profile) profile_wizard "$CURRENT_HOME/.profile";; inputrc) inputrc_wizard "$CURRENT_HOME/.inputrc";; starship) starship_wizard "$CURRENT_HOME/.config/starship.toml";; esac; done; }

nvim_full_wizard(){
 f=$CURRENT_HOME/.config/nvim/init.lua; mkdir -p "$(dirname "$f")"; [ -e "$f" ] || write_file "$f" 644 ''
 opts=$(ui_checklist 'Neovim configuration wizard' 'Select Neovim options.' number 'Line numbers' on relativenumber 'Relative line numbers' off cursorline 'Highlight current line' on mouse 'Mouse support' on clipboard 'System clipboard' off wrap 'Wrap long lines' off breakindent 'Preserve indentation while wrapping' on ignorecase 'Case-insensitive search' on smartcase 'Case-sensitive when uppercase used' on incsearch 'Incremental search' on hlsearch 'Highlight matches' on expandtab 'Use spaces instead of tabs' on autoindent 'Automatic indentation' on smartindent 'Smart indentation' on termguicolors '24-bit colors' on signcolumn 'Always show sign column' on undofile 'Persistent undo' on splitright 'Vertical splits on right' on splitbelow 'Horizontal splits below' on listchars 'Show whitespace characters' off spell 'Spell checking' off diagnostics 'Virtual-text diagnostics' on completion 'Native completion menu' on treesitter 'Enable Treesitter when installed' off lsp 'Enable built-in LSP sample' off lazy 'Bootstrap lazy.nvim' off) || return
 tab=$(ui_input Neovim 'Tab width:' 4) || return
 body="-- Neovim options selected through TUI\nlocal o = vim.opt\no.tabstop = $tab\no.shiftwidth = $tab"
 for o in number relativenumber cursorline mouse clipboard wrap breakindent ignorecase smartcase incsearch hlsearch expandtab autoindent smartindent termguicolors signcolumn undofile splitright splitbelow spell; do if wiz_has "$opts" "$o"; then case $o in mouse) body="$body\no.mouse = 'a'";; clipboard) body="$body\no.clipboard = 'unnamedplus'";; signcolumn) body="$body\no.signcolumn = 'yes'";; *) body="$body\no.$o = true";; esac; else case $o in wrap|spell|relativenumber|clipboard) body="$body\no.$o = false";; esac; fi; done
 wiz_has "$opts" listchars && body="$body\no.list = true\no.listchars = { tab = '» ', trail = '·', nbsp = '␣' }"
 wiz_has "$opts" diagnostics && body="$body\nvim.diagnostic.config({ virtual_text = true, signs = true, underline = true })"
 wiz_has "$opts" completion && body="$body\no.completeopt = { 'menu', 'menuone', 'noselect' }"
 wiz_has "$opts" treesitter && body="$body\npcall(function() require('nvim-treesitter.configs').setup({ highlight = { enable = true }, indent = { enable = true } }) end)"
 wiz_has "$opts" lsp && body="$body\npcall(function() vim.lsp.enable('lua_ls') end)"
 wiz_has "$opts" lazy && body="$body\nlocal lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'\nif not vim.uv.fs_stat(lazypath) then vim.fn.system({'git','clone','--filter=blob:none','https://github.com/folke/lazy.nvim.git','--branch=stable',lazypath}) end\nvim.opt.rtp:prepend(lazypath)\nrequire('lazy').setup({})"
 wiz_replace "$f" nvim-wizard "$body"
}

micro_full_wizard(){
 f=$CURRENT_HOME/.config/micro/settings.json; mkdir -p "$(dirname "$f")"
 opts=$(ui_checklist 'Micro configuration wizard' 'Select Micro settings.' autosu 'Request privilege when saving protected files' off autoclose 'Auto-close brackets and quotes' on autoindent 'Automatic indentation' on autosave 'Automatically save changes' off clipboard 'Use terminal clipboard' on cursorline 'Highlight current line' on diffgutter 'Show version-control changes' on eofnewline 'Ensure final newline' on hlsearch 'Highlight search matches' on ignorecase 'Case-insensitive search' on incsearch 'Incremental search' on infobar 'Show information bar' on mouse 'Mouse support' on parsecursor 'Parse cursor escape sequences' on rmtrailingws 'Remove trailing whitespace' off ruler 'Show ruler' on savecursor 'Remember cursor positions' on saveundo 'Persistent undo' on scrollmargin 'Keep cursor away from edge' on softwrap 'Wrap long lines' off statusformat 'Detailed status line' on syntax 'Syntax highlighting' on tabstospaces 'Convert tabs to spaces' on) || return
 tab=$(ui_input Micro 'Tab width:' 4) || return; scheme=$(ui_input Micro 'Color scheme:' default) || return
 body='{'; first=yes
 for o in autosu autoclose autoindent autosave clipboard cursorline diffgutter eofnewline hlsearch ignorecase incsearch infobar mouse parsecursor rmtrailingws ruler savecursor saveundo softwrap syntax tabstospaces; do val=false; wiz_has "$opts" "$o" && val=true; [ "$first" = yes ] || body="$body,"; body="$body\n  \"$o\": $val"; first=no; done
 body="$body,\n  \"tabsize\": $tab,\n  \"colorscheme\": \"$scheme\",\n  \"scrollmargin\": 3,\n  \"statusformatl\": \"$(printf '%s' '${filename} ${modified}')\"\n}"
 write_file "$f" 644 "$body"; ui_msg Micro "Saved $f"
}

helix_full_wizard(){
 f=$CURRENT_HOME/.config/helix/config.toml; mkdir -p "$(dirname "$f")"
 opts=$(ui_checklist 'Helix configuration wizard' 'Select Helix options.' line 'Absolute line numbers' on relative 'Relative line numbers' off mouse Mouse on clipboard 'Clipboard integration' on autoformat 'Format on save' off autosave 'Auto-save after delay' off cursorline 'Highlight current line' on gutters 'Diagnostics, line numbers and changes gutters' on indentguides 'Indent guides' on truecolor 'Force true color' on rulers 'Show column ruler' off whitespace 'Render whitespace' off bufferline 'Show multiple-buffer line' on colorpreview 'Show color swatches' on completion 'Automatic completion' on signature 'Signature help' on lsp 'Display LSP messages' on) || return
 theme=$(ui_input Helix 'Theme:' default) || return; idle=$(ui_input Helix 'Idle timeout milliseconds:' 250) || return
 ln=absolute; wiz_has "$opts" relative && ln=relative
 body="theme = \"$theme\"\n[editor]\nline-number = \"$ln\"\nidle-timeout = $idle"
 for o in mouse autoformat cursorline truecolor colorpreview completion signature; do val=false; wiz_has "$opts" "$o" && val=true; key=$o; case $o in autoformat) key=auto-format;; cursorline) key=cursorline;; truecolor) key=true-color;; colorpreview) key=color-modes;; completion) key=auto-completion;; signature) key=auto-signature-help;; esac; body="$body\n$key = $val"; done
 wiz_has "$opts" bufferline && body="$body\nbufferline = \"multiple\""
 wiz_has "$opts" gutters && body="$body\ngutters = [\"diagnostics\", \"spacer\", \"line-numbers\", \"spacer\", \"diff\"]"
 wiz_has "$opts" rulers && body="$body\nrulers = [80, 120]"
 wiz_has "$opts" indentguides && body="$body\n[editor.indent-guides]\nrender = true"
 wiz_has "$opts" whitespace && body="$body\n[editor.whitespace.render]\nspace = \"all\"\ntab = \"all\"\nnewline = \"none\""
 wiz_has "$opts" lsp && body="$body\n[editor.lsp]\ndisplay-messages = true\ndisplay-inlay-hints = true"
 write_file "$f" 644 "$body"; ui_msg Helix "Saved $f"
}

emacs_full_wizard(){
 f=$CURRENT_HOME/.emacs.d/init.el; mkdir -p "$(dirname "$f")"; [ -e "$f" ] || write_file "$f" 644 ''
 opts=$(ui_checklist 'Emacs configuration wizard' 'Select Emacs options.' startup 'Hide startup screen' on toolbar 'Hide toolbar' on menubar 'Hide menu bar' off scrollbar 'Hide scroll bar' on linenumbers 'Display line numbers' on column 'Display column number' on paren 'Highlight matching parentheses' on electric 'Electric pair mode' on delete 'Selection typing replaces region' on backup 'Create backup files' off autosave 'Create auto-save files' off tabs 'Use spaces instead of tabs' on trailing 'Highlight trailing whitespace' off recent 'Recent files menu' on saveplace 'Remember cursor positions' on history 'Persist minibuffer history' on package 'Initialize package manager' on usepackage 'Bootstrap use-package' off) || return
 tab=$(ui_input Emacs 'Default indentation width:' 4) || return
 body=";; Emacs options selected through TUI\n(setq-default tab-width $tab)"
 wiz_has "$opts" startup && body="$body\n(setq inhibit-startup-screen t)"
 wiz_has "$opts" toolbar && body="$body\n(tool-bar-mode -1)"
 wiz_has "$opts" menubar || body="$body\n(menu-bar-mode -1)"
 wiz_has "$opts" scrollbar && body="$body\n(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))"
 wiz_has "$opts" linenumbers && body="$body\n(global-display-line-numbers-mode 1)"
 wiz_has "$opts" column && body="$body\n(column-number-mode 1)"
 wiz_has "$opts" paren && body="$body\n(show-paren-mode 1)"
 wiz_has "$opts" electric && body="$body\n(electric-pair-mode 1)"
 wiz_has "$opts" delete && body="$body\n(delete-selection-mode 1)"
 wiz_has "$opts" backup || body="$body\n(setq make-backup-files nil)"
 wiz_has "$opts" autosave || body="$body\n(setq auto-save-default nil)"
 wiz_has "$opts" tabs && body="$body\n(setq-default indent-tabs-mode nil)"
 wiz_has "$opts" trailing && body="$body\n(setq-default show-trailing-whitespace t)"
 wiz_has "$opts" recent && body="$body\n(recentf-mode 1)"
 wiz_has "$opts" saveplace && body="$body\n(save-place-mode 1)"
 wiz_has "$opts" history && body="$body\n(savehist-mode 1)"
 wiz_has "$opts" package && body="$body\n(require 'package)\n(package-initialize)"
 wiz_has "$opts" usepackage && body="$body\n(unless (package-installed-p 'use-package) (package-refresh-contents) (package-install 'use-package))\n(eval-when-compile (require 'use-package))"
 wiz_replace "$f" emacs-wizard "$body"
}

editor_wizards_menu(){ while :; do c=$(ui_menu 'Editor configuration wizards' 'Configure editors through selectable options.' nano 'Nano option wizard' vim 'Vim option wizard' nvim 'Neovim Lua wizard' micro 'Micro settings wizard' helix 'Helix TOML wizard' emacs 'Emacs Lisp wizard') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in nano) nano_wizard "$CURRENT_HOME/.nanorc";; vim) vim_wizard "$CURRENT_HOME/.vimrc";; nvim) nvim_full_wizard;; micro) micro_full_wizard;; helix) helix_full_wizard;; emacs) emacs_full_wizard;; esac; done; }

terminal_full_wizard(){
 opts=$(ui_checklist 'Terminal environment wizard' 'Select terminal and pager behavior.' truecolor 'Advertise true-color support' on utf8 'Use UTF-8 locale' on title 'Set dynamic terminal title' on bracketed 'Enable bracketed-paste helpers' on osc52 'Install OSC52 clipboard helper function' off bell 'Disable audible bell' on dircolors 'Enable dircolors when available' on less 'Configure less pager' on man 'Configure man-page pager' on gpgtty 'Export GPG_TTY' on sshagent 'Start/reuse ssh-agent' off tmuxauto 'Attach to tmux on remote login' off) || return
 term=$(ui_input Terminal 'TERM value:' xterm-256color) || return; lang=$(ui_input Terminal 'UTF-8 locale:' C.UTF-8) || return
 body="export TERM='$term'"
 wiz_has "$opts" truecolor && body="$body\nexport COLORTERM=truecolor"
 wiz_has "$opts" utf8 && body="$body\nexport LANG='$lang'\nexport LC_CTYPE='$lang'"
 wiz_has "$opts" title && body="$body\ncase \$TERM in xterm*|screen*|tmux*) PROMPT_COMMAND=\"printf '\\\\033]0;%s@%s:%s\\\\007' '\\$USER' '\\$(hostname)' '\\$PWD';\${PROMPT_COMMAND:-}\";; esac"
 wiz_has "$opts" bracketed && body="$body\nbind 'set enable-bracketed-paste on' 2>/dev/null || true"
 wiz_has "$opts" osc52 && body="$body\nosc52(){ printf '\\\\033]52;c;%s\\\\a' \"\$(printf %s \"\$*\" | base64 | tr -d '\\\\n')\"; }"
 wiz_has "$opts" bell && body="$body\nbind 'set bell-style none' 2>/dev/null || true"
 wiz_has "$opts" dircolors && body="$body\ncommand -v dircolors >/dev/null 2>&1 && eval \"\$(dircolors -b)\""
 wiz_has "$opts" less && body="$body\nexport LESS='-FRX --mouse --wheel-lines=3'\nexport LESSHISTFILE=-"
 wiz_has "$opts" man && body="$body\nexport MANPAGER='less -R'"
 wiz_has "$opts" gpgtty && body="$body\nexport GPG_TTY=\$(tty 2>/dev/null || true)"
 wiz_has "$opts" sshagent && body="$body\nif command -v ssh-agent >/dev/null 2>&1 && [ -z \"\${SSH_AUTH_SOCK:-}\" ]; then eval \"\$(ssh-agent -s)\" >/dev/null; fi"
 wiz_has "$opts" tmuxauto && body="$body\n[ -n \"\${SSH_CONNECTION:-}\" ] && [ -z \"\${TMUX:-}\" ] && command -v tmux >/dev/null 2>&1 && tmux attach || tmux new"
 wiz_replace "$CURRENT_HOME/.profile" terminal-wizard "$body"
}

screen_wizard(){ f=$CURRENT_HOME/.screenrc; opts=$(ui_checklist 'GNU Screen wizard' 'Select GNU Screen behavior.' startup 'Hide startup message' on scrollback 'Large scrollback buffer' on utf8 UTF-8 on altscreen 'Preserve alternate screen' on hardstatus 'Show status line' on autodetach 'Detach on hangup' on vbell 'Visual bell' off mouse 'Mouse tracking' off login 'Write utmp login records' off) || return; hist=$(ui_input Screen 'Scrollback lines:' 20000) || return; body='# GNU Screen options selected through TUI'; wiz_has "$opts" startup && body="$body\nstartup_message off"; wiz_has "$opts" scrollback && body="$body\ndefscrollback $hist"; wiz_has "$opts" utf8 && body="$body\ndefutf8 on\nencoding UTF-8 UTF-8"; wiz_has "$opts" altscreen && body="$body\naltscreen on"; wiz_has "$opts" hardstatus && body="$body\nhardstatus alwayslastline\nhardstatus string '%{= kw}%-Lw%{= bw}%n*%f %t%{-}%+Lw %= %Y-%m-%d %c'"; wiz_has "$opts" autodetach && body="$body\nautodetach on"; wiz_has "$opts" vbell && body="$body\nvbell on" || body="$body\nvbell off"; wiz_has "$opts" mouse && body="$body\ntermcapinfo xterm* ti@:te@"; wiz_has "$opts" login || body="$body\ndeflogin off"; wiz_replace "$f" screen-wizard "$body"; }

less_wizard(){ f=$CURRENT_HOME/.lesskey; opts=$(ui_checklist 'Less pager wizard' 'Select pager options.' quit 'Quit if content fits one screen' on raw 'Show ANSI colors' on chop 'Chop long lines' off status 'Verbose status prompt' on incsearch 'Incremental search' on mouse 'Mouse scrolling' on history 'Disable history file' on case 'Smart-case search' on) || return; flags=''; wiz_has "$opts" quit && flags="$flags -F"; wiz_has "$opts" raw && flags="$flags -R"; wiz_has "$opts" chop && flags="$flags -S"; wiz_has "$opts" status && flags="$flags -M"; wiz_has "$opts" incsearch && flags="$flags --incsearch"; wiz_has "$opts" mouse && flags="$flags --mouse"; wiz_has "$opts" case && flags="$flags -i"; body="export LESS='${flags# }'"; wiz_has "$opts" history && body="$body\nexport LESSHISTFILE=-"; wiz_replace "$CURRENT_HOME/.profile" less-wizard "$body"; }

terminal_wizards_menu(){ while :; do c=$(ui_menu 'Terminal configuration wizards' 'Configure terminal behavior without raw editing.' env 'Terminal environment wizard' tmux 'Tmux wizard' screen 'GNU Screen wizard' inputrc 'Readline/inputrc wizard' less 'Less pager wizard' starship 'Starship prompt wizard' test 'Terminal capability test') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in env) terminal_full_wizard;; tmux) tmux_wizard "$CURRENT_HOME/.tmux.conf";; screen) screen_wizard;; inputrc) inputrc_wizard "$CURRENT_HOME/.inputrc";; less) less_wizard;; starship) starship_wizard "$CURRENT_HOME/.config/starship.toml";; test) terminal_test;; esac; done; }

nnn_full_wizard(){ opts=$(ui_checklist 'nnn configuration wizard' 'Select nnn environment options.' hidden 'Show hidden files' on detail 'Detailed mode' off autoenter 'Enter directories on selection' on du 'Show disk usage' off cli 'Use current terminal directory' on trash 'Use trash instead of permanent delete where supported' on plugins 'Enable plugin mappings' on fifo 'Create preview FIFO' on colors 'Use four context colors' on opener 'Configure desktop opener' off bookmarks 'Install sample bookmarks' on) || return; o=''; wiz_has "$opts" hidden && o="${o}H"; wiz_has "$opts" detail && o="${o}d"; wiz_has "$opts" autoenter && o="${o}A"; wiz_has "$opts" du && o="${o}S"; body="export NNN_OPTS='$o'"; wiz_has "$opts" colors && body="$body\nexport NNN_COLORS='1234'"; wiz_has "$opts" plugins && body="$body\nexport NNN_PLUG='f:finder;o:fzopen;p:preview-tui;d:dups;t:nmount'"; wiz_has "$opts" fifo && body="$body\nexport NNN_FIFO=/tmp/nnn.fifo"; wiz_has "$opts" opener && body="$body\nexport NNN_OPENER=xdg-open"; wiz_has "$opts" bookmarks && body="$body\nexport NNN_BMS='h:~;c:~/.config;t:/tmp;r:/'"; wiz_replace "$CURRENT_HOME/.profile" nnn-wizard "$body"; }

lf_full_wizard(){ f=$CURRENT_HOME/.config/lf/lfrc; mkdir -p "$(dirname "$f")"; opts=$(ui_checklist 'lf configuration wizard' 'Select lf options.' hidden 'Show hidden files' on icons 'Show icons' off preview 'Enable file previews' on drawbox 'Draw borders' on ignorecase 'Case-insensitive search' on smartcase 'Smart-case search' on shellflag 'Use safe shell flags' on number 'Show line numbers' off relativenumber 'Relative line numbers' off dirfirst 'Directories first' on info 'Detailed information column' on history 'Persist command history' on sixel 'Enable sixel previews' off) || return; period=$(ui_input lf 'Preview refresh period:' 0) || return; body='# lf options selected through TUI'; for o in hidden icons preview drawbox ignorecase smartcase number relativenumber dirfirst; do val=false; wiz_has "$opts" "$o" && val=true; body="$body\nset $o $val"; done; body="$body\nset period $period"; wiz_has "$opts" shellflag && body="$body\nset shell sh\nset shellflag '-eu'"; wiz_has "$opts" info && body="$body\nset info size:time"; wiz_has "$opts" history && body="$body\nset history true"; wiz_has "$opts" sixel && body="$body\nset sixel true"; body="$body\nmap gh cd ~\nmap D delete\nmap <c-q> quit"; wiz_replace "$f" lf-wizard "$body"; }

ranger_full_wizard(){ f=$CURRENT_HOME/.config/ranger/rc.conf; mkdir -p "$(dirname "$f")"; opts=$(ui_checklist 'Ranger configuration wizard' 'Select Ranger options.' hidden 'Show hidden files' on preview 'Preview files' on images 'Preview images' off vcs 'Version-control integration' on borders 'Draw borders' on mouse 'Mouse support' on collapse 'Collapse preview directories' on dirname 'Display directory in title' on confirm 'Confirm multiple deletes' on natural 'Natural sorting' on dirsfirst 'Directories first' on reverse 'Reverse sort' off wrap 'Wrap scrolling' on flush 'Flush input after shortcuts' on) || return; method=$(ui_radiolist Ranger 'Image preview method' w3m w3m off sixel sixel off kitty kitty off ueberzug ueberzug off none Disabled on) || return; body='# Ranger options selected through TUI'; for o in hidden preview vcs mouse collapse; do key=$o; case $o in hidden) key=show_hidden;; preview) key=preview_files;; vcs) key=vcs_aware;; collapse) key=collapse_preview;; esac; val=false; wiz_has "$opts" "$o" && val=true; body="$body\nset $key $val"; done; wiz_has "$opts" borders && body="$body\nset draw_borders both" || body="$body\nset draw_borders none"; wiz_has "$opts" dirname && body="$body\nset dirname_in_tabs true"; wiz_has "$opts" confirm && body="$body\nset confirm_on_delete multiple"; wiz_has "$opts" natural && body="$body\nset sort natural"; wiz_has "$opts" dirsfirst && body="$body\nset sort_directories_first true"; wiz_has "$opts" reverse && body="$body\nset sort_reverse true"; wiz_has "$opts" wrap && body="$body\nset wrap_scroll true"; wiz_has "$opts" flush && body="$body\nset flushinput true"; [ "$method" != none ] && body="$body\nset preview_images true\nset preview_images_method $method" || body="$body\nset preview_images false"; wiz_replace "$f" ranger-wizard "$body"; }

yazi_full_wizard(){ f=$CURRENT_HOME/.config/yazi/yazi.toml; mkdir -p "$(dirname "$f")"; opts=$(ui_checklist 'Yazi configuration wizard' 'Select Yazi options.' hidden 'Show hidden files' on linemode 'Show file sizes' on dirfirst 'Directories first' on symlink 'Follow symbolic links' off scrolloff 'Keep cursor away from edges' on mouse 'Mouse events' on trash 'Use trash' on ratio 'Three-pane layout' on preview 'Preview files' on image 'Image previews' off sortcase 'Case-sensitive sort' off natural 'Natural sorting' on reverse 'Reverse order' off) || return; sort=$(ui_radiolist Yazi 'Sort by' natural Natural on modified Modified off size Size off extension Extension off alphabetic Alphabetic off) || return; body="[manager]\nshow_hidden = $(wiz_has "$opts" hidden && echo true || echo false)\nsort_by = \"$sort\"\nsort_reverse = $(wiz_has "$opts" reverse && echo true || echo false)\nsort_dir_first = $(wiz_has "$opts" dirfirst && echo true || echo false)\nsort_sensitive = $(wiz_has "$opts" sortcase && echo true || echo false)\nlinemode = \"$(wiz_has "$opts" linemode && echo size || echo none)\"\nscrolloff = $(wiz_has "$opts" scrolloff && echo 5 || echo 0)\nmouse_events = [\"click\", \"scroll\"]\n[preview]\nwrap = \"yes\"\nimage_filter = \"triangle\""; wiz_replace "$f" yazi-wizard "$body"; }

mc_full_wizard(){ f=$CURRENT_HOME/.config/mc/ini; mkdir -p "$(dirname "$f")"; opts=$(ui_checklist 'Midnight Commander wizard' 'Select Midnight Commander settings.' hidden 'Show hidden files' on backup 'Show backup files' off confirmdelete 'Confirm deletion' on confirmexit 'Confirm exit' off internaledit 'Use internal editor' off internalview 'Use internal viewer' on mouse 'Mouse support' on lynx 'Lynx-like motion' on fastreload 'Fast directory reload' on mixall 'Mix files and directories' off dropmenu 'Drop-down menus' on oldesc 'Old ESC key behavior' off) || return; body='[Midnight-Commander]'; for o in hidden backup confirmdelete confirmexit internaledit internalview mouse lynx fastreload mixall dropmenu oldesc; do case $o in hidden) key=show_hidden;; backup) key=show_backups;; confirmdelete) key=confirm_delete;; confirmexit) key=confirm_exit;; internaledit) key=use_internal_edit;; internalview) key=use_internal_view;; mouse) key=mouse_move_pages;; lynx) key=classic_progressbar;; fastreload) key=fast_refresh;; mixall) key=mix_all_files;; dropmenu) key=drop_menus;; oldesc) key=old_esc_mode;; esac; val=false; wiz_has "$opts" "$o" && val=true; body="$body\n$key=$val"; done; wiz_replace "$f" mc-wizard "$body"; }

tere_full_wizard(){ f=$CURRENT_HOME/.config/tere/config.toml; mkdir -p "$(dirname "$f")"; opts=$(ui_checklist 'Tere configuration wizard' 'Select Tere options.' mouse 'Mouse support' on hidden 'Show hidden files' on icons 'Show icons' off case 'Case-sensitive search' off directories 'Directories before files' on gitignore 'Respect .gitignore' on searchslash 'Start search only with /' on quit 'Map Ctrl-Q to quit' on find 'Map Ctrl-F to search' on delete 'Map Ctrl-D to delete' on) || return; body="mouse = $(wiz_has "$opts" mouse && echo true || echo false)\nshow_hidden = $(wiz_has "$opts" hidden && echo true || echo false)\nicons = $(wiz_has "$opts" icons && echo true || echo false)\ncase_sensitive = $(wiz_has "$opts" case && echo true || echo false)\ndirectories_first = $(wiz_has "$opts" directories && echo true || echo false)\nrespect_gitignore = $(wiz_has "$opts" gitignore && echo true || echo false)"; wiz_has "$opts" searchslash && body="$body\nsearch_mode = \"explicit\""; wiz_has "$opts" quit && body="$body\n[keybindings]\nquit = \"ctrl-q\""; wiz_has "$opts" find && body="$body\nsearch = \"ctrl-f\""; wiz_has "$opts" delete && body="$body\ndelete = \"ctrl-d\""; wiz_replace "$f" tere-wizard "$body"; }

file_manager_wizards_menu(){ while :; do c=$(ui_menu 'File-manager configuration wizards' 'Configure file managers with selectable options.' nnn 'nnn environment wizard' lf 'lf configuration wizard' ranger 'Ranger configuration wizard' yazi 'Yazi TOML wizard' mc 'Midnight Commander wizard' tere 'Tere wizard') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in nnn) nnn_full_wizard;; lf) lf_full_wizard;; ranger) ranger_full_wizard;; yazi) yazi_full_wizard;; mc) mc_full_wizard;; tere) tere_full_wizard;; esac; done; }
