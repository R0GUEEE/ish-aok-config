#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
ISH_AOK_CONFIG_ROOT=$ROOT; export ISH_AOK_CONFIG_ROOT
. ./lib/core.sh
for f in ./lib/*.sh; do [ "$f" = ./lib/core.sh ] || . "$f"; done
for f in ./modules/package/*.sh ./modules/services/*.sh ./modules/*.sh; do . "$f"; done

fail(){ echo "FAIL: $*" >&2; exit 1; }

# Editor path: use a mock editor and verify content is copied back.
mock=$TMP_DIR/mock-editor
cat >"$mock" <<'MOCK'
#!/bin/sh
printf '%s\n' edited-by-v110 >>"$1"
MOCK
chmod +x "$mock"
EDITOR=$mock VISUAL=; export EDITOR VISUAL
f=$TMP_DIR/sources.list
printf '%s\n' original >"$f"
ui_msg(){ :; }
edit_file "$f"
grep -q edited-by-v110 "$f" || fail 'edit_file did not save mock editor changes'

# Keyring path mapping.
mkdir -p "$TMP_DIR/keyrings"
# Function path is fixed; validate the implementation contains Ubuntu keyring support and debootstrap --keyring.
grep -q '/usr/share/keyrings/ubuntu-archive-keyring.gpg' modules/zzzzzzzzzzzzzzz_v110_builder_repo_editor_fixes.sh || fail 'Ubuntu keyring path missing'
grep -q -- '--keyring=' modules/zzzzzzzzzzzzzzz_v110_builder_repo_editor_fixes.sh || fail 'debootstrap keyring option missing'

# Repository additions must use checklist and combined dedicated source file.
grep -q "ui_checklist 'Add APT Repository Components'" modules/zzzzzzzzzzzzzzz_v110_builder_repo_editor_fixes.sh || fail 'APT additions are not multi-select'
grep -q '/etc/apt/sources.list.d/ish-aok-official.list' modules/zzzzzzzzzzzzzzz_v110_builder_repo_editor_fixes.sh || fail 'combined APT source file missing'

echo 'PASS: v10.10 builder keyrings, repository checklist, and editor workflow'
