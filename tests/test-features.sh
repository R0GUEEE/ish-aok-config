#!/bin/bash
# Tests for the package-manager, catalogue and file-manager feature work.
# Network is never required: the plugin registry runs against local fixtures.
set -uo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf -- "$tmpdir"' EXIT

failures=0
checks=0

# Each check re-sources the full tool, so the suite takes a couple of minutes.
# An optional range lets it be run in slices on a constrained runner:
#   ./test-features.sh          run everything
#   ./test-features.sh 1 25     run checks 1 through 25 only
FROM=${1:-1}
TO=${2:-999}

check() {
    local description="$1"; shift
    checks=$((checks + 1))
    if [ "$checks" -lt "$FROM" ] || [ "$checks" -gt "$TO" ]; then
        printf 'ok %d - %s # skip (outside the requested range)\n' "$checks" "$description"
        return
    fi
    if timeout 60 "$@" </dev/null >/dev/null 2>&1; then
        printf 'ok %d - %s\n' "$checks" "$description"
    else
        printf 'not ok %d - %s\n' "$checks" "$description"
        failures=$((failures + 1))
    fi
}

export SYSTUI_TMP_ROOT="$tmpdir"
export SYSTUI_CONFIG_DIR="$tmpdir/cfg"
export SYSTUI_LOGFILE="$tmpdir/systui.log"
export SYSTUI_FM_PLUGIN_CACHE="$tmpdir/fmcache"
export HOME="$tmpdir/home"
export PROJECT_DIR TMPD="$tmpdir"
mkdir -p "$HOME" "$SYSTUI_FM_PLUGIN_CACHE"

# Shared preamble: load systui with the interactive layer stubbed out. Helper
# scripts source this rather than nesting quotes inside bash -c.
cat > "$tmpdir/preamble.sh" <<'PRE'
. "$PROJECT_DIR/src/core/config.sh"
. "$PROJECT_DIR/src/core/common.sh"
. "$PROJECT_DIR/src/core/tui-widgets.sh"
. "$PROJECT_DIR/src/features/sysconfig.sh"
tui_msg()  { :; }
tui_text() { :; }
tui_yesno(){ return 0; }
tui_input(){ printf '%s\n' "${3:-}"; }
run_cmd()  { local d="$1"; shift; "$@" >/dev/null 2>&1; }
select_all() { shift 2; while [ $# -ge 3 ]; do printf '%s ' "$1"; shift 3; done; }
PRE

# Helper scripts are invoked as `bash <path>` rather than through a wrapper
# function: `check` runs its arguments under `timeout`, which needs a real
# executable and cannot call a shell function.
helper() { cat > "$tmpdir/$1.sh"; }    # define a helper script from stdin
run() { bash "$tmpdir/$1.sh"; }        # for direct (non-check) invocation

# ---------------------------------------------------------------------------
# Fixtures mirroring the three upstream index formats
# ---------------------------------------------------------------------------
cat > "$tmpdir/yazi.md" <<'EOF'
## Plugins
### Previewers
<details>
<summary>
<a href="https://github.com/gesellkammer/audio-preview.yazi">audio-preview.yazi</a> - Preview soundfiles as a spectrogram using <a href="https://github.com/chirlu/sox">sox</a>.
</summary>
</details>
### Jumping
<details>
<summary>
<a href="https://github.com/dedukun/relative-motions.yazi">relative-motions.yazi</a> - Vim-like relative motions.
</summary>
</details>
EOF

cat > "$tmpdir/ranger.md" <<'EOF'
- [ranger-archives](https://github.com/maximtrp/ranger-archives), support for creating and extracting archives
- [ranger-zoxide](https://github.com/jchook/ranger-zoxide), zoxide integration for a smarter `cd` command
- [plugin_dir_diff](https://github.com/alex8866/eranger/blob/master/ranger/config/plugins/x.py)
EOF

cat > "$tmpdir/nnn.md" <<'EOF'
| Plugin | Description | Lang | Dependencies |
| --- | --- | --- | --- |
| [autojump](autojump) | Navigate to dir/path | sh | [autojump](https://github.com/wting/autojump) |
| [preview-tui](preview-tui) | Preview hovered entry | sh | tmux 3.0+, [bat](https://github.com/x/bat) |
EOF

cat > "$tmpdir/poison.tsv" <<'EOF'
bad-repo	X	bad-repo	../../etc	.config/yazi/plugins/a	traversal in repo
bad-dest	X	bad-dest	owner/repo	../../../etc/cron.d/x	traversal in destination
bad-host	X	bad-host	https://evil.example/x	.config/yazi/plugins/c	url not owner/repo
outside	X	outside	owner/repo	.ssh/authorized_keys	destination outside config dir
EOF

# ---------------------------------------------------------------------------
# File-manager plugin registry
# ---------------------------------------------------------------------------

helper parse <<'EOF'
. "$TMPD/preamble.sh"
for fm in yazi ranger nnn; do
    fm_plugin_parse "$fm" "$TMPD/$fm.md" "$TMPD/$fm.tsv" || exit 1
    fm_plugin_catalog_valid "$fm" "$TMPD/$fm.tsv" || exit 1
done
EOF
check "all three upstream index formats parse into valid catalogues" bash "$tmpdir/parse.sh"

check "yazi parser keeps descriptions containing nested links" \
    grep -q "spectrogram using sox" "$tmpdir/yazi.tsv"
check "yazi parser records the category heading" \
    awk -F'\t' '$1 ~ /audio-preview/ && $2 == "Previewers"' "$tmpdir/yazi.tsv"
check "ranger parser skips deep links into a repository" \
    bash -c '! grep -q plugin_dir_diff "$TMPD/ranger.tsv"'
check "nnn parser cleans markdown out of the dependency column" \
    bash -c 'grep -q "needs: autojump" "$TMPD/nnn.tsv" && ! grep -q "https://" "$TMPD/nnn.tsv"'

# Every in-tree nnn plugin shares one repository, so deduplication has to key on
# the destination. Keying on the repository collapsed the whole set to one row.
helper dedupe <<'EOF'
. "$TMPD/preamble.sh"
cp "$TMPD/nnn.tsv" "$SYSTUI_FM_PLUGIN_CACHE/nnn.tsv"
n=$(fm_plugin_registry nnn | awk -F'\t' '$4 == "jarun/nnn"' | grep -c .)
[ "$n" -ge 2 ]
EOF
check "registry deduplicates on destination, not repository" bash "$tmpdir/dedupe.sh"

helper merge <<'EOF'
. "$TMPD/preamble.sh"
cp "$TMPD/yazi.tsv" "$SYSTUI_FM_PLUGIN_CACHE/yazi.tsv"
fm_plugin_registry yazi | grep -q Curated || exit 1
fm_plugin_registry yazi | grep -q Previewers || exit 1
d=$(fm_plugin_registry yazi | awk -F'\t' '{print $5}' | sort | uniq -d)
[ -z "$d" ]
EOF
check "registry merges curated with fetched and keeps destinations unique" bash "$tmpdir/merge.sh"

helper poison <<'EOF'
. "$TMPD/preamble.sh"
fm_plugin_catalog_valid yazi "$TMPD/poison.tsv" && exit 1
cp "$TMPD/poison.tsv" "$SYSTUI_FM_PLUGIN_CACHE/yazi.tsv"
n=$(fm_plugin_registry yazi | grep -c -e bad-repo -e bad-dest -e bad-host -e outside)
[ "$n" = 0 ]
EOF
check "poisoned catalogue rows are rejected and filtered on read" bash "$tmpdir/poison.sh"

helper validators <<'EOF'
. "$TMPD/preamble.sh"
fm_plugin_valid_repo 'owner/repo' || exit 1
fm_plugin_valid_repo 'https://github.com/owner/repo' && exit 1
fm_plugin_valid_repo '../../etc' && exit 1
fm_plugin_valid_repo 'owner/repo; rm -rf /' && exit 1
fm_plugin_valid_dest yazi '.config/yazi/plugins/x' || exit 1
fm_plugin_valid_dest yazi '.local/share/yazi/x' || exit 1
fm_plugin_valid_dest yazi '.ssh/authorized_keys' && exit 1
fm_plugin_valid_dest yazi '.config/yazi/../../x' && exit 1
exit 0
EOF
check "repository and destination validators reject hostile values" bash "$tmpdir/validators.sh"

helper nofetch <<'EOF'
. "$TMPD/preamble.sh"
fm_plugin_index_url lf >/dev/null 2>&1 && exit 1
[ "$(fm_plugin_registry lf | grep -c .)" -gt 0 ]
EOF
check "file managers without an index still expose the curated list" bash "$tmpdir/nofetch.sh"

# ---------------------------------------------------------------------------
# File-manager configuration menus
# ---------------------------------------------------------------------------

helper genfm <<'EOF'
. "$TMPD/preamble.sh"
fm_target_user()    { id -un; }
fm_home()           { echo "$TMPD/fmhome"; }
HOME="$TMPD/fmhome"
fm_backup_config()  { :; }
fm_as_user()        { bash -c "$2"; }
chown()             { :; }
tui_check()         { select_all "$@"; }
mkdir -p "$TMPD/fmhome"
for fm in lf tere yazi ranger nnn vifm broot xplr; do "fm_configure_${fm}_menu"; done
EOF
run genfm >/dev/null 2>&1

for pair in "lf:.config/lf/lfrc" "tere:.bashrc" "yazi:.config/yazi/yazi.toml" \
            "yazi:.config/yazi/keymap.toml" "ranger:.config/ranger/rc.conf" \
            "vifm:.config/vifm/vifmrc" "broot:.config/broot/conf.hjson" \
            "xplr:.config/xplr/init.lua" "nnn:.profile"; do
    check "${pair%%:*} writes ${pair#*:}" test -s "$tmpdir/fmhome/${pair#*:}"
done

helper lfshell <<'EOF'
awk '/\{\{/{f=1;next} /^\}\}/{f=0;next} f' "$TMPD/fmhome/.config/lf/lfrc" > "$TMPD/lf.sh"
sh -n "$TMPD/lf.sh"
EOF
check "generated lfrc embeds only POSIX shell" bash "$tmpdir/lfshell.sh"

helper yazitoml <<'EOF'
python3 - <<'PY'
import os, sys
try: import tomllib as T
except ImportError:
    try: import tomli as T
    except ImportError: sys.exit(0)
d = os.environ["TMPD"]
T.load(open(d + "/fmhome/.config/yazi/yazi.toml", "rb"))
T.load(open(d + "/fmhome/.config/yazi/keymap.toml", "rb"))
PY
EOF
check "generated yazi TOML parses" bash "$tmpdir/yazitoml.sh"

check "generated bashrc fragment is valid bash" bash -n "$tmpdir/fmhome/.bashrc"
# The Ctrl-T bindings mix quote styles; interpolating them through a quoted
# heredoc previously leaked the backslash escapes into the user's rc file.
check "no escaped quotes leak into the shell rc fragments" \
    bash -c '! grep -q "\\\\\"" "$TMPD/fmhome/.bashrc" "$TMPD/fmhome/.zshrc"'

helper hjson <<'EOF'
python3 - <<'PY'
import os
s = open(os.environ["TMPD"] + "/fmhome/.config/broot/conf.hjson").read()
assert s.count("{") == s.count("}"), "unbalanced braces"
assert s.count("[") == s.count("]"), "unbalanced brackets"
PY
EOF
check "broot hjson has balanced delimiters" bash "$tmpdir/hjson.sh"

check "no unexpanded helper calls leak into any generated config" \
    bash -c '! grep -rq fm_selection_has "$TMPD/fmhome"'

helper optcount <<'EOF'
for fm in lf tere yazi ranger nnn vifm broot xplr; do
    n=$(sed -n "/^fm_configure_${fm}_menu() {/,/^    mkdir -p\|^    opts=\|^    fm_as_user\|^    frag=/p" \
        "$PROJECT_DIR/src/features/sysconfig.sh" | grep -cE '"[^"]+" +(on|off)')
    [ "$n" -ge 15 ] || { echo "$fm has only $n options" >&2; exit 1; }
done
EOF
check "every file manager exposes at least 15 options" bash "$tmpdir/optcount.sh"

# ---------------------------------------------------------------------------
# Catalogue: checklist-first browsing
# ---------------------------------------------------------------------------

cat > "$tmpdir/cat-base.sh" <<'EOF'
. "$TMPD/preamble.sh"
PM=apt
is_pkg_installed() { case "$1" in htop|git) return 0;; *) return 1;; esac; }
app_native_name()  { echo "$1"; }
cat_title()        { echo Test; }
show_warnings()    { :; }
CAT_APPS[testcat]='htop|htop|Process viewer
git|git|Version control
ncdu|ncdu|Disk usage'
pm_install() { echo "INSTALL $*"; exit 0; }
pm_remove()  { echo "REMOVE $*";  exit 0; }
tui_msg()    { echo "MSG $1";     exit 0; }
EOF

helper cat-prechecked <<'EOF'
. "$TMPD/cat-base.sh"
# The stub records the tag/state pairs and then reports cancellation. Returning
# non-zero is what makes browse_category return; `exit` would only leave the
# command substitution it runs in, and the menu loop would spin forever.
tui_check() {
    shift 2
    : > "$TMPD/prechecked"
    while [ $# -ge 3 ]; do printf '%s:%s ' "$1" "$3" >> "$TMPD/prechecked"; shift 3; done
    return 1
}
browse_category testcat >/dev/null 2>&1
out=$(cat "$TMPD/prechecked")
case "$out" in *htop:on*git:on*ncdu:off*) exit 0 ;; *) echo "got: $out" >&2; exit 1 ;; esac
EOF
check "catalogue pre-checks entries that are already installed" bash "$tmpdir/cat-prechecked.sh"

helper cat-install <<'EOF'
. "$TMPD/cat-base.sh"
tui_check() { echo "htop git ncdu"; }
[ "$(browse_category testcat)" = "INSTALL ncdu" ]
EOF
check "checking a new entry installs it" bash "$tmpdir/cat-install.sh"

helper cat-remove <<'EOF'
. "$TMPD/cat-base.sh"
tui_check() { echo "htop"; }
case "$(browse_category testcat)" in REMOVE*git*) exit 0 ;; *) exit 1 ;; esac
EOF
check "unchecking an installed entry offers removal" bash "$tmpdir/cat-remove.sh"

helper cat-nochange <<'EOF'
. "$TMPD/cat-base.sh"
tui_check() { echo "htop git"; }
[ "$(browse_category testcat)" = "MSG No changes" ]
EOF
check "an unchanged selection performs no package operations" bash "$tmpdir/cat-nochange.sh"

helper cat-details <<'EOF'
. "$TMPD/cat-base.sh"
# Fire the details path once, then cancel. A stub that returned the same
# selection forever would keep the menu loop spinning.
rm -f "$TMPD/details-seen"
tui_check() {
    if [ -e "$TMPD/details-seen" ]; then return 1; fi
    : > "$TMPD/details-seen"
    echo "__details ncdu"
}
tui_menu() { echo __back; }
case "$(browse_category testcat)" in INSTALL*|REMOVE*) exit 1 ;; *) exit 0 ;; esac
EOF
check "the details entry never triggers an install" bash "$tmpdir/cat-details.sh"

check "the separate bulk-install entry is gone" \
    bash -c '! grep -q ">> Bulk install" "$PROJECT_DIR/src/features/sysconfig.sh"'

helper pkgpm <<'EOF'
b=$(sed -n '/^is_pkg_installed() {/,/^}$/p' "$PROJECT_DIR/src/features/sysconfig.sh")
for pm in apt apk pacman dnf yum zypper xbps emerge; do
    printf '%s' "$b" | grep -q "$pm" || { echo "missing $pm" >&2; exit 1; }
done
EOF
check "is_pkg_installed covers all eight package managers" bash "$tmpdir/pkgpm.sh"

# ---------------------------------------------------------------------------
# Package-manager advanced menus
# ---------------------------------------------------------------------------

helper advcoverage <<'EOF'
b=$(sed -n '/^pm_advanced_menu() {/,/^}$/p' "$PROJECT_DIR/src/features/sysconfig.sh")
for m in apt aptfast nala aptitude pacman yay paru dnf yum zypper apk xbps emerge \
         flatpak snap nix brew pip pipx npm pnpm yarn cargo gem composer go native; do
    printf '%s' "$b" | grep -qE "(^| |\|)$m[)|]" || { echo "missing $m" >&2; exit 1; }
done
EOF
check "every manager in the list resolves to an advanced menu" bash "$tmpdir/advcoverage.sh"

helper advrun <<'EOF'
. "$TMPD/preamble.sh"
tui_check() { select_all "$@"; }
for m in pip npm pnpm yarn cargo gem go composer pipx nix brew; do
    pm_advanced_menu "$m" >/dev/null 2>&1
done
EOF
run advrun >/dev/null 2>&1

for pair in "pip:.config/pip/pip.conf" "npm:.npmrc" "pnpm:.config/pnpm/rc" "yarn:.yarnrc" \
            "cargo:.cargo/config.toml" "gem:.gemrc" "go:.config/go/env" \
            "composer:.config/composer/config.json" "nix:.config/nix/nix.conf" \
            "brew:.config/homebrew/brew.env"; do
    check "${pair%%:*} advanced menu writes ${pair#*:}" test -s "$HOME/${pair#*:}"
done

helper cargotoml <<'EOF'
python3 - <<'PY'
import os, sys
try: import tomllib as T
except ImportError:
    try: import tomli as T
    except ImportError: sys.exit(0)
T.load(open(os.environ["HOME"] + "/.cargo/config.toml", "rb"))
PY
EOF
check "cargo config is valid TOML" bash "$tmpdir/cargotoml.sh"

# `offline` and `git-fetch-with-cli` both belong to [net]; emitting one without
# the header put it under whichever table happened to precede it.
helper cargonet <<'EOF'
rm -rf "$TMPD/h2"; mkdir -p "$TMPD/h2"
HOME="$TMPD/h2" bash -c '. "$TMPD/preamble.sh"; tui_check() { echo "sparse offline"; }; pm_adv_lang cargo' >/dev/null 2>&1
python3 - <<'PY'
import os, sys
try: import tomllib as T
except ImportError:
    try: import tomli as T
    except ImportError: sys.exit(0)
d = T.load(open(os.environ["TMPD"] + "/h2/.cargo/config.toml", "rb"))
assert d.get("net", {}).get("offline") is True, d
assert "offline" not in d.get("registries", {}).get("crates-io", {}), d
PY
EOF
check "cargo places offline under [net] without git-fetch-with-cli" bash "$tmpdir/cargonet.sh"

helper composerjson <<'EOF'
python3 -c "import json,os; json.load(open(os.environ['HOME']+'/.config/composer/config.json'))"
EOF
check "composer config is valid JSON" bash "$tmpdir/composerjson.sh"

helper idempotent <<'EOF'
cp "$HOME/.npmrc" "$TMPD/npmrc.before"
cp "$HOME/.config/pip/pip.conf" "$TMPD/pip.before"
bash "$TMPD/advrun.sh" >/dev/null 2>&1
diff -q "$TMPD/npmrc.before" "$HOME/.npmrc" >/dev/null || exit 1
diff -q "$TMPD/pip.before" "$HOME/.config/pip/pip.conf" >/dev/null || exit 1
[ "$(grep -c systui-npm "$HOME/.npmrc")" = 2 ]
EOF
check "advanced menus are idempotent and keep one managed block" bash "$tmpdir/idempotent.sh"

helper advwired <<'EOF'
f="$PROJECT_DIR/src/features/sysconfig.sh"
grep -q 'advanced) pm_advanced_menu "\$id"' "$f" || exit 1
grep -q 'advanced) pm_advanced_menu "\$PM"' "$f" || exit 1
grep -q 'advanced) pm_advanced_menu flatpak' "$f" || exit 1
grep -q 'advanced) pm_advanced_menu snap' "$f" || exit 1
EOF
check "advanced entries are wired into the manager menus" bash "$tmpdir/advwired.sh"

printf '1..%d\n' "$checks"
[ "$failures" -eq 0 ]
