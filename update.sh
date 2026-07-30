#!/usr/bin/env bash
###############################################################################
# systui Update Script
# Updates the source checkout from Git and reinstalls systui.
###############################################################################

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
STATE_DIR="${SYSTUI_STATE_DIR:-/etc/systui}"
SOURCE_FILE="$STATE_DIR/source-dir"
REMOTE_FILE="$STATE_DIR/source-url"
BRANCH_FILE="$STATE_DIR/source-branch"
BACKUP_DIR="${SYSTUI_BACKUP_DIR:-/var/backups/systui}"
FORCE=0
NO_DEPS=0

usage() {
    cat <<USAGE
Usage: $0 [options]

Options:
  --force       Reset the checkout to the remote branch after backing it up.
  --no-deps     Skip dependency installation during reinstall.
  -h, --help    Show this help.

Environment overrides:
  SYSTUI_REPO_URL   Git repository URL when no origin is available.
  SYSTUI_BRANCH     Branch to update (defaults to current branch or remote HEAD).
  INSTALL_PREFIX    Installation prefix (default: /usr/local).
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --force) FORCE=1 ;;
        --no-deps) NO_DEPS=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

info()  { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()   { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git is required to update systui."

# Re-exec as root so the reinstall and state update are consistent.
if [ "$(id -u)" -ne 0 ]; then
    elevate_args=()
    [ "$FORCE" -eq 1 ] && elevate_args+=(--force)
    [ "$NO_DEPS" -eq 1 ] && elevate_args+=(--no-deps)
    command -v sudo >/dev/null 2>&1 || die "Run this script as root."
    exec sudo --preserve-env=SYSTUI_REPO_URL,SYSTUI_BRANCH,INSTALL_PREFIX,SYSTUI_STATE_DIR,SYSTUI_BACKUP_DIR \
        "$0" "${elevate_args[@]}"
fi

mkdir -p "$STATE_DIR" "$BACKUP_DIR"

SOURCE_DIR=""
if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    SOURCE_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
elif [ -r "$SOURCE_FILE" ]; then
    SOURCE_DIR="$(cat "$SOURCE_FILE")"
fi

REPO_URL="${SYSTUI_REPO_URL:-}"
if [ -z "$REPO_URL" ] && [ -n "$SOURCE_DIR" ] && git -C "$SOURCE_DIR" remote get-url origin >/dev/null 2>&1; then
    REPO_URL="$(git -C "$SOURCE_DIR" remote get-url origin)"
elif [ -z "$REPO_URL" ] && [ -r "$REMOTE_FILE" ]; then
    REPO_URL="$(cat "$REMOTE_FILE")"
fi

if [ -z "$SOURCE_DIR" ] || ! git -C "$SOURCE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    [ -n "$REPO_URL" ] || die "No Git source was found. Run from a Git clone or set SYSTUI_REPO_URL."
    SOURCE_DIR="${SYSTUI_SOURCE_DIR:-/opt/systui-src}"
    if [ -e "$SOURCE_DIR" ] && [ ! -d "$SOURCE_DIR/.git" ]; then
        die "$SOURCE_DIR exists but is not a Git checkout. Set SYSTUI_SOURCE_DIR to another path."
    fi
    if [ ! -d "$SOURCE_DIR/.git" ]; then
        info "Cloning $REPO_URL into $SOURCE_DIR..."
        git clone "$REPO_URL" "$SOURCE_DIR"
    fi
fi

REPO_URL="${REPO_URL:-$(git -C "$SOURCE_DIR" remote get-url origin 2>/dev/null || true)}"
[ -n "$REPO_URL" ] || die "The source checkout has no origin remote. Set SYSTUI_REPO_URL."

BRANCH="${SYSTUI_BRANCH:-}"
if [ -z "$BRANCH" ]; then
    BRANCH="$(git -C "$SOURCE_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
fi
if [ -z "$BRANCH" ] && [ -r "$BRANCH_FILE" ]; then
    BRANCH="$(cat "$BRANCH_FILE")"
fi
if [ -z "$BRANCH" ]; then
    BRANCH="$(git -C "$SOURCE_DIR" remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -n1)"
fi
[ -n "$BRANCH" ] || BRANCH="main"

info "Source: $SOURCE_DIR"
info "Remote: $REPO_URL"
info "Branch: $BRANCH"

git -C "$SOURCE_DIR" remote set-url origin "$REPO_URL"
git -C "$SOURCE_DIR" -c safe.directory="$SOURCE_DIR" fetch --prune origin "$BRANCH"

STAMP="$(date +%Y%m%d-%H%M%S)"
if [ -n "$(git -C "$SOURCE_DIR" status --porcelain)" ]; then
    BACKUP="$BACKUP_DIR/source-$STAMP.tar.gz"
    info "Backing up modified source files to $BACKUP..."
    tar -C "$(dirname "$SOURCE_DIR")" -czf "$BACKUP" "$(basename "$SOURCE_DIR")"

    if [ "$FORCE" -eq 1 ]; then
        warn "Resetting modified checkout to origin/$BRANCH."
        git -C "$SOURCE_DIR" reset --hard "origin/$BRANCH"
        git -C "$SOURCE_DIR" clean -fd
    else
        info "Stashing local changes before update..."
        git -C "$SOURCE_DIR" stash push --include-untracked -m "systui-update-$STAMP" >/dev/null
        git -C "$SOURCE_DIR" checkout "$BRANCH" 2>/dev/null || git -C "$SOURCE_DIR" checkout -b "$BRANCH" --track "origin/$BRANCH"
        git -C "$SOURCE_DIR" merge --ff-only "origin/$BRANCH"
        warn "Local changes remain preserved in Git stash: systui-update-$STAMP"
    fi
else
    git -C "$SOURCE_DIR" checkout "$BRANCH" 2>/dev/null || git -C "$SOURCE_DIR" checkout -b "$BRANCH" --track "origin/$BRANCH"
    git -C "$SOURCE_DIR" merge --ff-only "origin/$BRANCH"
fi

[ -x "$SOURCE_DIR/install.sh" ] || chmod +x "$SOURCE_DIR/install.sh"
[ -f "$SOURCE_DIR/install.sh" ] || die "Updated source does not contain install.sh."

info "Reinstalling systui..."
if [ "$NO_DEPS" -eq 1 ]; then
    SYSTUI_SKIP_DEPS=1 INSTALL_PREFIX="$INSTALL_PREFIX" "$SOURCE_DIR/install.sh"
else
    INSTALL_PREFIX="$INSTALL_PREFIX" "$SOURCE_DIR/install.sh"
fi

printf '%s\n' "$SOURCE_DIR" > "$SOURCE_FILE"
printf '%s\n' "$REPO_URL" > "$REMOTE_FILE"
printf '%s\n' "$BRANCH" > "$BRANCH_FILE"
chmod 0644 "$SOURCE_FILE" "$REMOTE_FILE" "$BRANCH_FILE"

ok "systui updated and reinstalled successfully."
