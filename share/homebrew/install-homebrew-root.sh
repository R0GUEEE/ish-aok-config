#!/usr/bin/env bash
# Root-managed Homebrew installer for Debian arm64 on iSH-AOK.
#
# WARNING: Homebrew does not officially support operation as root. This script
# installs a small LD_PRELOAD compatibility shim so Homebrew and its subprocesses
# observe a non-root UID while retaining the root process's real filesystem access.

set -Eeuo pipefail

readonly BREW_PREFIX="/home/linuxbrew/.linuxbrew"
readonly BREW_REPOSITORY="${BREW_PREFIX}/Homebrew"
readonly REAL_BREW="${BREW_REPOSITORY}/bin/brew"
readonly BREW_LINK="${BREW_PREFIX}/bin/brew"
readonly ROOT_WRAPPER="/usr/local/bin/brew"
readonly SHIM_DIR="/usr/local/lib/homebrew-root"
readonly SHIM_SOURCE="${SHIM_DIR}/fakeuid.c"
readonly SHIM_LIBRARY="${SHIM_DIR}/libhomebrew_fakeuid.so"
readonly ROOT_ENV_DIR="/etc/systui"
readonly ROOT_ENV_FILE="${ROOT_ENV_DIR}/homebrew.env"
readonly PROFILE_FILE="/etc/profile.d/homebrew.sh"
readonly FAKE_UID="1000"
readonly FAKE_GID="1000"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run this installer as root."
[[ $(uname -s) == Linux ]] || die "This installer only supports Linux."

case "$(uname -m)" in
  aarch64|arm64) ;;
  *) die "This installer requires Debian arm64/aarch64. Detected: $(uname -m)" ;;
esac

[[ -r /etc/os-release ]] || die "/etc/os-release is missing."
# shellcheck disable=SC1091
. /etc/os-release
[[ ${ID:-} == debian || ${ID_LIKE:-} == *debian* ]] || \
  die "This installer requires Debian or a Debian-derived rootfs. Detected: ${PRETTY_NAME:-unknown}."

if ! grep -Eqi 'ish([_-]?aok)?|ish_aok|ish' \
  /proc/version /proc/sys/kernel/osrelease 2>/dev/null; then
  warn "iSH-AOK was not positively detected; continuing because Debian arm64 checks passed."
fi

export DEBIAN_FRONTEND=noninteractive

log "Installing Debian build dependencies"
apt-get update
apt-get install -y --no-install-recommends \
  bash build-essential ca-certificates curl file git procps \
  gcc g++ make libc6-dev patch perl python3 ruby \
  tar gzip bzip2 xz-utils unzip

log "Preparing root-owned Homebrew prefix"
install -d -m 0755 -o root -g root /home/linuxbrew
install -d -m 0755 -o root -g root "$BREW_PREFIX"

if [[ -d "$BREW_REPOSITORY" && ! -x "$REAL_BREW" ]]; then
  log "Removing incomplete Homebrew checkout"
  rm -rf "$BREW_REPOSITORY"
fi

if [[ ! -x "$REAL_BREW" ]]; then
  log "Cloning a lightweight Homebrew checkout"
  git \
    -c http.version=HTTP/1.1 \
    -c http.maxRequests=1 \
    -c core.compression=0 \
    clone \
    --depth=1 \
    --single-branch \
    --branch=main \
    --no-tags \
    https://github.com/Homebrew/brew.git \
    "$BREW_REPOSITORY"
else
  log "Existing Homebrew checkout found"
fi

log "Creating Homebrew directory layout"
install -d -m 0755 -o root -g root \
  "$BREW_PREFIX/bin" \
  "$BREW_PREFIX/sbin" \
  "$BREW_PREFIX/etc" \
  "$BREW_PREFIX/include" \
  "$BREW_PREFIX/lib" \
  "$BREW_PREFIX/opt" \
  "$BREW_PREFIX/share" \
  "$BREW_PREFIX/share/man" \
  "$BREW_PREFIX/share/info" \
  "$BREW_PREFIX/var" \
  "$BREW_PREFIX/var/homebrew" \
  "$BREW_PREFIX/var/homebrew/linked" \
  "$BREW_PREFIX/Cellar" \
  "$BREW_PREFIX/Caskroom" \
  "$BREW_PREFIX/Frameworks"

ln -sfn "$REAL_BREW" "$BREW_LINK"
chown -h root:root "$BREW_LINK"
chown -R root:root /home/linuxbrew

log "Building Homebrew root-compatibility UID shim"
install -d -m 0755 -o root -g root "$SHIM_DIR"
cat > "$SHIM_SOURCE" <<EOF_C
#define _GNU_SOURCE
#include <sys/types.h>
#include <unistd.h>

uid_t getuid(void)  { return (uid_t)${FAKE_UID}; }
uid_t geteuid(void) { return (uid_t)${FAKE_UID}; }
gid_t getgid(void)  { return (gid_t)${FAKE_GID}; }
gid_t getegid(void) { return (gid_t)${FAKE_GID}; }

int getresuid(uid_t *ruid, uid_t *euid, uid_t *suid) {
    if (ruid) *ruid = (uid_t)${FAKE_UID};
    if (euid) *euid = (uid_t)${FAKE_UID};
    if (suid) *suid = (uid_t)${FAKE_UID};
    return 0;
}

int getresgid(gid_t *rgid, gid_t *egid, gid_t *sgid) {
    if (rgid) *rgid = (gid_t)${FAKE_GID};
    if (egid) *egid = (gid_t)${FAKE_GID};
    if (sgid) *sgid = (gid_t)${FAKE_GID};
    return 0;
}
EOF_C

gcc -shared -fPIC -O2 -Wall -Wextra \
  -o "$SHIM_LIBRARY" "$SHIM_SOURCE"
chmod 0755 "$SHIM_LIBRARY"

log "Installing permanent Homebrew compatibility environment"
install -d -m 0755 -o root -g root "$ROOT_ENV_DIR"
if [[ ! -f "$ROOT_ENV_FILE" ]]; then
  cat > "$ROOT_ENV_FILE" <<EOF_ENV
# systui managed Homebrew root-compat defaults
HOMEBREW_ROOT_COMPAT=1
HOMEBREW_NO_ANALYTICS=1
HOMEBREW_NO_ENV_HINTS=1
HOMEBREW_NO_AUTO_UPDATE=1
HOMEBREW_NO_INSTALL_CLEANUP=1
EOF_ENV
  chmod 0644 "$ROOT_ENV_FILE"
fi

log "Installing root-enabled brew wrapper"
cat > "$ROOT_WRAPPER" <<EOF_WRAPPER
#!/usr/bin/env bash
set -e

export HOME="/root"
export USER="root"
export LOGNAME="root"
export HOMEBREW_PREFIX="$BREW_PREFIX"
export HOMEBREW_CELLAR="$BREW_PREFIX/Cellar"
export HOMEBREW_REPOSITORY="$BREW_REPOSITORY"
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
if [ -r "$ROOT_ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ROOT_ENV_FILE"
fi
: "\${HOMEBREW_NO_ANALYTICS:=1}"
: "\${HOMEBREW_NO_ENV_HINTS:=1}"
: "\${HOMEBREW_NO_AUTO_UPDATE:=1}"
: "\${HOMEBREW_NO_INSTALL_CLEANUP:=1}"
export HOMEBREW_NO_ANALYTICS HOMEBREW_NO_ENV_HINTS HOMEBREW_NO_AUTO_UPDATE HOMEBREW_NO_INSTALL_CLEANUP
export LD_PRELOAD="$SHIM_LIBRARY\${LD_PRELOAD:+:\$LD_PRELOAD}"

exec "$REAL_BREW" "\$@"
EOF_WRAPPER
chmod 0755 "$ROOT_WRAPPER"

# Prevent the prefix symlink from bypassing the root wrapper.
rm -f "$BREW_LINK"
ln -s "$ROOT_WRAPPER" "$BREW_LINK"

log "Writing system-wide root Homebrew environment"
cat > "$PROFILE_FILE" <<EOF_PROFILE
export HOMEBREW_PREFIX="$BREW_PREFIX"
export HOMEBREW_CELLAR="$BREW_PREFIX/Cellar"
export HOMEBREW_REPOSITORY="$BREW_REPOSITORY"
export PATH="/usr/local/bin:$BREW_PREFIX/bin:$BREW_PREFIX/sbin:\$PATH"
export MANPATH="$BREW_PREFIX/share/man\${MANPATH+:\$MANPATH}"
export INFOPATH="$BREW_PREFIX/share/info\${INFOPATH+:\$INFOPATH}"
[ -r "$ROOT_ENV_FILE" ] && . "$ROOT_ENV_FILE"
EOF_PROFILE
chmod 0644 "$PROFILE_FILE"

for profile in /root/.bashrc /root/.profile; do
  touch "$profile"
  if ! grep -Fq '/etc/profile.d/homebrew.sh' "$profile"; then
    cat >> "$profile" <<'EOF_PROFILE_LOAD'

# Root-managed Homebrew for Debian arm64 on iSH-AOK
[ -r /etc/profile.d/homebrew.sh ] && . /etc/profile.d/homebrew.sh
EOF_PROFILE_LOAD
  fi
done

log "Verifying root-enabled Homebrew"
"$ROOT_WRAPPER" --version

cat <<EOF_DONE

Root-managed Homebrew installation completed.

Use Homebrew directly as root:
  source /etc/profile.d/homebrew.sh
  brew --version
  brew install <formula>
  brew update
  brew upgrade

Compatibility layer assets:
  Wrapper: $ROOT_WRAPPER
  Env file: $ROOT_ENV_FILE
  Shim:    $SHIM_LIBRARY

Homebrew root mode is an unsupported iSH-AOK compatibility configuration.
EOF_DONE
