#!/bin/sh
plugin_options_list(){ app=$1; case $app in
 omb_plugins) cat <<'EOF'
aliases|General alias helpers
alias-completion|Complete aliases as commands
apt|APT command aliases
archive|Archive extraction helpers
aws|AWS CLI helpers
bashmarks|Directory bookmarks
brew|Homebrew helpers
clipboard|Clipboard helpers
command-not-found|Command-not-found integration
composer|Composer helpers
docker|Docker aliases
docker-compose|Docker Compose aliases
extract|Universal archive extraction
fasd|Fasd navigation
git|Git aliases and status helpers
git-flow|Git Flow helpers
git-lfs|Git LFS helpers
golang|Go helpers
history|History helpers
javascript|JavaScript helpers
jenv|Java environment helpers
kubectl|Kubernetes helpers
make|Make helpers
man|Enhanced man helpers
npm|npm aliases
nvm|Node Version Manager
path|PATH utilities
pip|pip helpers
python|Python helpers
rbenv|Ruby environment
ruby|Ruby helpers
ssh|SSH helpers
sudo|Prefix previous command with sudo
tmux|Tmux helpers
virtualenv|Python virtualenv helpers
zoxide|Zoxide integration
EOF
;;
 omb_themes) cat <<'EOF'
agnoster|Powerline-style prompt
axin|Compact prompt
bakke|Minimal Git prompt
binaryanomaly|Two-line developer prompt
bobby|Readable Git prompt
brainy|Information-rich prompt
candy|Colorful compact prompt
cooperkid|Two-line prompt
cupcake|Compact modern prompt
doubletime|Two-line time prompt
dulcie|Minimal prompt
font|Simple font-safe prompt
iterate|Git-aware prompt
kitsune|Minimal status prompt
modern|Modern Bash prompt
nwinkler|Git and Ruby prompt
powerbash10k|Powerlevel-style Bash prompt
powerline|Powerline prompt
pure|Minimal pure-style prompt
sexy|Simple colored prompt
sirup|Compact status prompt
slick|Slick Git prompt
standard|Default Oh My Bash prompt
tonotdo|Minimal two-line prompt
wanelo|Path and Git prompt
EOF
;;
 omz_plugins) cat <<'EOF'
git|Git aliases and functions
sudo|Escape twice to prefix sudo
history|History aliases
colored-man-pages|Colorized manual pages
command-not-found|Command-not-found integration
extract|Universal archive extraction
fzf|fzf integration
zoxide|Zoxide integration
autojump|Autojump navigation
dirhistory|Directory history
copyfile|Copy file content to clipboard
copypath|Copy current path
safe-paste|Protect multiline paste
web-search|Search engines from shell
ssh-agent|Automatic SSH agent
gpg-agent|GPG agent integration
tmux|Tmux aliases
tmuxinator|Tmuxinator integration
systemd|systemctl aliases
vi-mode|Vi keybindings
aliases|Alias inspection
common-aliases|Common aliases
rsync|Rsync aliases
encode64|Base64 helpers
urltools|URL encode/decode
archlinux|Pacman aliases
debian|Debian aliases
ubuntu|Ubuntu helpers
apt|APT aliases
apk|Alpine APK aliases
brew|Homebrew aliases
docker|Docker aliases
docker-compose|Docker Compose aliases
kubectl|Kubernetes aliases
helm|Helm completion
terraform|Terraform completion
aws|AWS completion
gcloud|Google Cloud helpers
node|Node helpers
npm|npm completion
nvm|NVM integration
pnpm|pnpm helpers
yarn|Yarn completion
python|Python helpers
pip|pip completion
poetry|Poetry completion
rust|Rust helpers
golang|Go helpers
cargo|Cargo completion
mvn|Maven completion
gradle|Gradle completion
EOF
;;
 omz_themes) cat <<'EOF'
robbyrussell|Default compact theme
agnoster|Powerline Git theme
bira|Two-line Git theme
bureau|Detailed two-line theme
candy|Colorful compact theme
clean|Minimal prompt
cloud|Cloud-style prompt
dallas|Readable Git prompt
dst|Git status prompt
eastwood|Minimal user and path prompt
fino|Two-line prompt
fishy|Fish-inspired prompt
frontcube|Powerline theme
gallifrey|Compact status prompt
gentoo|Gentoo-style prompt
gnome|GNOME terminal theme
jreese|Minimal Git prompt
lambda|Lambda prompt
maran|Colorful theme
mira|Two-line prompt
mortalscumbag|Git-rich prompt
norm|Simple normal prompt
pygmalion|Powerline style
random|Random theme each shell
refined|Minimal refined prompt
risto|Compact prompt
simple|Simple theme
steeef|Two-line prompt
suvash|Minimal status prompt
tjkirch|Git prompt
wedisagree|Two-line path prompt
ys|Popular two-line theme
EOF
;;
 bashit_plugins) cat <<'EOF'
alias-completion|Alias completion
aws|AWS helpers
base|Base Bash-it functionality
battery|Battery status
browser|Browser helpers
dirs|Directory stack
extract|Archive extraction
fasd|Fasd integration
fzf|fzf integration
git|Git helpers
git-subrepo|Git subrepo helpers
go|Go helpers
history|History helpers
less-pretty-cat|Pretty cat via less
man|Manual page helpers
node|Node helpers
npm|npm helpers
nvm|NVM integration
projects|Project navigation
python|Python helpers
ruby|Ruby helpers
ssh|SSH helpers
tmux|Tmux helpers
virtualenv|Virtualenv helpers
zoxide|Zoxide integration
EOF
;;
 fish_plugins) cat <<'EOF'
jorgebucaran/autopair.fish|Automatic bracket pairing
jorgebucaran/fisher|Fisher plugin manager
patrickf1/fzf.fish|fzf integration
jorgebucaran/nvm.fish|Node version management
jorgebucaran/replay.fish|Replay Bash environment scripts
IlanCosman/tide@v6|Tide prompt
oh-my-fish/theme-bobthefish|Bobthefish prompt
meaningful-ooo/sponge|Remove failed commands from history
gazorby/fish-abbreviation-tips|Show abbreviation tips
laughedelic/pisces|Pair symbols automatically
franciscolourenco/done|Long-command notifications
edc/bass|Run Bash utilities in Fish
kidonng/zoxide.fish|Zoxide integration
jorgebucaran/hydro|Minimal prompt
jethrokuan/z|Directory jumping
jorgebucaran/getopts.fish|Argument parsing helper
EOF
;;
 vim_plugins) cat <<'EOF'
tpope/vim-sensible|Sensible defaults
tpope/vim-fugitive|Git integration
tpope/vim-surround|Surround text objects
tpope/vim-commentary|Comment operators
tpope/vim-repeat|Repeat plugin maps
preservim/nerdtree|File tree
junegunn/fzf.vim|fzf integration
itchyny/lightline.vim|Status line
vim-airline/vim-airline|Status line and tabline
airut/vim-gitgutter|Git change signs
dense-analysis/ale|Linting and fixing
sheerun/vim-polyglot|Language syntax collection
ycm-core/YouCompleteMe|Code completion
jiangmiao/auto-pairs|Automatic pairs
editorconfig/editorconfig-vim|EditorConfig support
morhetz/gruvbox|Gruvbox colorscheme
drakula/vim|Dracula colorscheme
catppuccin/vim|Catppuccin colorscheme
EOF
;;
 nvim_plugins) cat <<'EOF'
nvim-lua/plenary.nvim|Lua utility library
nvim-telescope/telescope.nvim|Fuzzy finder
nvim-treesitter/nvim-treesitter|Syntax parsing
neovim/nvim-lspconfig|LSP configuration
hrsh7th/nvim-cmp|Completion engine
hrsh7th/cmp-nvim-lsp|LSP completion source
L3MON4D3/LuaSnip|Snippet engine
nvim-tree/nvim-tree.lua|File tree
nvim-tree/nvim-web-devicons|File icons
lewis6991/gitsigns.nvim|Git signs
numToStr/Comment.nvim|Comment commands
windwp/nvim-autopairs|Automatic pairs
folke/which-key.nvim|Keybinding hints
folke/tokyonight.nvim|Tokyo Night theme
catppuccin/nvim|Catppuccin theme
nvim-lualine/lualine.nvim|Status line
akinsho/bufferline.nvim|Buffer tabs
stevearc/conform.nvim|Formatting
mfussenegger/nvim-lint|Linting
folke/trouble.nvim|Diagnostics list
EOF
;;
 tmux_plugins) cat <<'EOF'
tmux-plugins/tpm|Tmux Plugin Manager
tmux-plugins/tmux-sensible|Sensible defaults
tmux-plugins/tmux-resurrect|Save and restore sessions
tmux-plugins/tmux-continuum|Automatic session saving
tmux-plugins/tmux-yank|System clipboard integration
tmux-plugins/tmux-copycat|Enhanced text search
tmux-plugins/tmux-open|Open highlighted files and URLs
tmux-plugins/tmux-prefix-highlight|Prefix status indicator
tmux-plugins/tmux-cpu|CPU and RAM status
tmux-plugins/tmux-battery|Battery status
christoomey/vim-tmux-navigator|Vim/Tmux navigation
catppuccin/tmux|Catppuccin theme
dracula/tmux|Dracula theme
jimeh/tmux-themepack|Theme collection
EOF
;;
 nnn_plugins) cat <<'EOF'
autojump|Change directory using autojump
boom|Play random music directory
bulknew|Create multiple files and directories
chksum|Checksum files
clipboard-copier|Copy selection to clipboard
cmusq|Queue music in cmus
codex|Open selected file with Codex/editor workflow
convert|Convert media files
copyfile|Copy a file to destination
cp2path|Copy selected files to path
diffs|Show file differences
dragdrop|Drag and drop helper
dupes|Find duplicate files
edit|Edit file with configured editor
finder|macOS Finder integration
fzcd|fzf directory changer
fzopen|fzf file opener
gitroot|Jump to Git root
gpge|GPG encrypt selected files
gpgd|GPG decrypt selected files
hexview|Hex viewer
imgresize|Resize images
imgur|Upload image to Imgur
launch|Launch desktop file
mimelist|List MIME types
mocplay|Play files with moc
mount-to|Mount storage at selected path
nbak|Backup nnn configuration
nmount|Mount and unmount devices
openall|Open all selected files
organize|Organize files by extension
pdfread|Read PDF text
preview-tui|Terminal preview pane
preview-tabbed|Tabbed preview
pskill|Kill process interactively
renamer|Batch rename
rsynccp|Rsync copy
splitjoin|Split and join files
suedit|Edit file with elevated permissions
togglex|Toggle executable bit
trash-cli|Move files to trash
uidgid|Show ownership information
umounttree|Unmount mount tree
upload|Upload files
wall|Set wallpaper
x2sel|Copy selection to X clipboard
zoxide|Jump with zoxide
EOF
;;
 micro_plugins) cat <<'EOF'
autofmt|Automatic formatting
comment|Comment toggling
diff|Diff integration
editorconfig|EditorConfig support
filemanager|File manager pane
fzf|fzf integration
gotham|Gotham colorscheme
linter|Code linting
manipulator|Text manipulation
nordcolors|Nord colorscheme
plugin-channel|Plugin update channel
quickfix|Quickfix list
status|Enhanced status line
wc|Word count
EOF
;;
 lf_tools) cat <<'EOF'
previewer|Preview script integration
cleaner|Preview cache cleaner
open|MIME-aware opener
extract|Archive extraction command
fzf-select|fzf file selection
zoxide-jump|Zoxide directory jump
trash|Trash command
bulk-rename|Batch rename command
git-status|Git status integration
clipboard|Clipboard copy helper
EOF
;; esac; }
plugin_options_checklist(){ app=$1; title=$2; set --; oldifs=$IFS; IFS='|'; while read -r id desc; do [ -n "$id" ] || continue; set -- "$@" "$id" "$desc" off; done <<EOF
$(plugin_options_list "$app")
EOF
IFS=$oldifs; [ $# -gt 0 ] || return 1; ui_checklist "$title" 'Select plugins. Space toggles an item; Enter applies.' "$@"; }
