#!/bin/sh
# v10.11.0: target-distribution keyring bootstrap cache for RootFS builds.
# Foreign keyring packages are downloaded from the target distribution archive,
# extracted without installing them on the host, and supplied to debootstrap.

V111_KEYRING_CACHE=${ISH_AOK_KEYRING_CACHE:-$STATE_DIR/rootfs-keyrings}

v111_fetch(){
  url=$1 out=$2
  mkdir -p "$(dirname "$out")" || return 1
  if have curl; then
    curl -fL --retry 3 --connect-timeout 20 "$url" -o "$out"
  elif have wget; then
    wget -O "$out" "$url"
  else
    ui_msg 'Download required' 'Install curl or wget before downloading target-distribution keyrings.'
    return 1
  fi
}

v111_sha256(){
  if have sha256sum; then sha256sum "$1" | awk '{print $1}'
  elif have shasum; then shasum -a 256 "$1" | awk '{print $1}'
  else return 1
  fi
}

v111_unpack_packages_index(){
  src=$1 out=$2
  case $src in
    *.xz) have xz || { ui_msg 'XZ required' 'Install xz-utils before downloading archive metadata.'; return 1; }; xz -dc "$src" >"$out";;
    *.gz) have gzip || return 1; gzip -dc "$src" >"$out";;
    *) cp "$src" "$out";;
  esac
}

# Print "filename|sha256" for the requested package from a Debian Packages file.
v111_packages_record(){
  package=$1 index=$2
  awk -v wanted="$package" '
    BEGIN { active=0; filename=""; sha="" }
    /^Package: / {
      if (active && filename != "") { print filename "|" sha; exit }
      active=($2 == wanted); filename=""; sha=""; next
    }
    active && /^Filename: / { filename=$2; next }
    active && /^SHA256: / { sha=$2; next }
    /^$/ && active {
      if (filename != "") { print filename "|" sha; exit }
      active=0
    }
    END { if (active && filename != "") print filename "|" sha }
  ' "$index" | head -n 1
}

v111_distro_keyring_metadata(){
  # package|keyring-relative-path
  case $1 in
    ubuntu) printf '%s\n' 'ubuntu-keyring|usr/share/keyrings/ubuntu-archive-keyring.gpg';;
    debian) printf '%s\n' 'debian-archive-keyring|usr/share/keyrings/debian-archive-keyring.gpg';;
    devuan) printf '%s\n' 'devuan-keyring|usr/share/keyrings/devuan-archive-keyring.gpg';;
    kali) printf '%s\n' 'kali-archive-keyring|usr/share/keyrings/kali-archive-keyring.gpg';;
    raspbian) printf '%s\n' 'raspbian-archive-keyring|usr/share/keyrings/raspbian-archive-keyring.gpg';;
    *) return 1;;
  esac
}

v111_existing_or_cached_keyring(){
  distro=$1 suite=${2:-stable}
  existing=$(v110_keyring_path "$distro")
  [ -n "$existing" ] && { printf '%s\n' "$existing"; return 0; }
  meta=$(v111_distro_keyring_metadata "$distro") || return 1
  rel=${meta#*|}
  cached="$V111_KEYRING_CACHE/$distro/$suite/extracted/$rel"
  [ -s "$cached" ] && { printf '%s\n' "$cached"; return 0; }
  return 1
}

v111_archive_index_urls(){
  mirror=${1%/} suite=$2
  printf '%s\n' \
    "$mirror/dists/$suite/main/binary-all/Packages.xz" \
    "$mirror/dists/$suite/main/binary-all/Packages.gz"
}

v111_bootstrap_deb_keyring(){
  distro=$1 suite=$2 mirror=${3%/}
  meta=$(v111_distro_keyring_metadata "$distro") || return 1
  pkg=${meta%%|*}; rel=${meta#*|}
  cache="$V111_KEYRING_CACHE/$distro/$suite"
  extracted="$cache/extracted"
  key="$extracted/$rel"
  [ -s "$key" ] && { printf '%s\n' "$key"; return 0; }

  have dpkg-deb || {
    ui_msg 'dpkg-deb required' "The RootFS Builder needs dpkg-deb to extract $pkg without installing it on the host."
    return 1
  }
  mkdir -p "$cache" "$extracted" || return 1

  index_archive=''
  for url in $(v111_archive_index_urls "$mirror" "$suite"); do
    candidate="$cache/${url##*/}"
    if v111_fetch "$url" "$candidate"; then index_archive=$candidate; break; fi
    rm -f "$candidate"
  done
  [ -n "$index_archive" ] || {
    ui_msg 'Keyring metadata unavailable' "Could not download package metadata for $distro $suite from:\n$mirror\n\nCheck the suite and mirror, then retry."
    return 1
  }

  index="$cache/Packages"
  v111_unpack_packages_index "$index_archive" "$index" || return 1
  record=$(v111_packages_record "$pkg" "$index")
  filename=${record%%|*}; expected=${record#*|}
  [ -n "$filename" ] && [ "$filename" != "$record" ] || {
    ui_msg 'Keyring package not found' "Package $pkg was not found in the $distro $suite archive metadata."
    return 1
  }

  deb="$cache/${filename##*/}"
  v111_fetch "$mirror/$filename" "$deb" || return 1
  if [ -n "$expected" ]; then
    actual=$(v111_sha256 "$deb" 2>/dev/null || true)
    [ -z "$actual" ] || [ "$actual" = "$expected" ] || {
      rm -f "$deb"
      ui_msg 'Keyring verification failed' "The SHA-256 checksum for $pkg did not match the official archive metadata."
      return 1
    }
  fi

  rm -rf "$extracted"
  mkdir -p "$extracted" || return 1
  dpkg-deb -x "$deb" "$extracted" || return 1
  [ -s "$key" ] || {
    # Some releases use a versioned or differently named archive keyring.
    found=$(find "$extracted/usr/share/keyrings" -maxdepth 1 -type f -name "${distro}*archive*keyring*.gpg" 2>/dev/null | head -n 1)
    [ -n "$found" ] && key=$found
  }
  [ -s "$key" ] || {
    ui_msg 'Extracted keyring missing' "$pkg was downloaded and extracted, but no usable archive keyring was found."
    return 1
  }
  printf '%s\n' "$key"
}

v111_builder_keyring_preflight(){
  distro=$1 suite=${2:-stable} mirror=${3:-}
  case $distro in devuan|debian|ubuntu|kali|raspbian) :;; *) return 0;; esac
  v111_existing_or_cached_keyring "$distro" "$suite" >/dev/null 2>&1 && return 0
  [ -n "$mirror" ] || return 1
  ui_yesno 'Missing target keyring' "The $distro archive keyring is not available on this host. Download and cache it from the target distribution's official archive without installing foreign packages on the host?" || return 1
  key=$(v111_bootstrap_deb_keyring "$distro" "$suite" "$mirror") || return 1
  [ -s "$key" ] || return 1
  ui_msg 'Target keyring ready' "Cached $distro archive keyring:\n$key"
}

# Override the previous host-package preflight. Optional suite/mirror arguments
# retain compatibility with older callers.
v110_builder_keyring_preflight(){
  v111_builder_keyring_preflight "$@"
}

v110_debootstrap_run(){
  distro=$1 suite=$2 arch=$3 dest=$4 mirror=$5 variant=${6:-minbase} includes=${7:-}
  v111_builder_keyring_preflight "$distro" "$suite" "$mirror" || return 1
  key=$(v111_existing_or_cached_keyring "$distro" "$suite") || {
    key=$(v111_bootstrap_deb_keyring "$distro" "$suite" "$mirror") || return 1
  }
  set -- debootstrap --arch="$arch" --variant="$variant" --keyring="$key"
  [ -n "$includes" ] && set -- "$@" --include="$(printf '%s' "$includes" | tr ' ' ',')"
  set -- "$@" "$suite" "$dest"
  [ -n "$mirror" ] && set -- "$@" "$mirror"
  run_capture "Build $distro RootFS" as_root "$@"
}

v111_cached_keyrings_report(){
  find "$V111_KEYRING_CACHE" -type f -path '*/usr/share/keyrings/*.gpg' 2>/dev/null | sort
}

v111_clear_keyring_cache(){
  ui_yesno 'Clear RootFS keyring cache' "Remove cached target-distribution keyrings from:\n$V111_KEYRING_CACHE" || return 0
  rm -rf "$V111_KEYRING_CACHE"
  mkdir -p "$V111_KEYRING_CACHE"
  ui_msg 'Keyring cache' 'Cached RootFS keyrings were removed.'
}

# Replace the old host-package keyring menu with cache-aware actions.
v110_rootfs_keyrings_menu(){
  while :; do
    c=$(ui_menu 'RootFS Builder Keyrings' 'Target keyrings are downloaded from official target archives and extracted without installing foreign packages on the host.' \
      ubuntu 'Download/cache Ubuntu archive keyring' \
      debian 'Download/cache Debian archive keyring' \
      devuan 'Download/cache Devuan archive keyring' \
      list 'List cached RootFS keyrings' \
      clear 'Clear RootFS keyring cache' \
      back Back) || return 0
    case $c in
      ubuntu) suite=$(ui_input Ubuntu 'Release/suite:' noble) || continue; mirror=$(ui_input Ubuntu 'Official archive mirror:' http://ports.ubuntu.com/ubuntu-ports) || continue; key=$(v111_bootstrap_deb_keyring ubuntu "$suite" "$mirror") && ui_msg 'Ubuntu keyring ready' "$key";;
      debian) suite=$(ui_input Debian 'Release/suite:' trixie) || continue; mirror=$(ui_input Debian 'Official archive mirror:' https://deb.debian.org/debian) || continue; key=$(v111_bootstrap_deb_keyring debian "$suite" "$mirror") && ui_msg 'Debian keyring ready' "$key";;
      devuan) suite=$(ui_input Devuan 'Release/suite:' excalibur) || continue; mirror=$(ui_input Devuan 'Official archive mirror:' https://deb.devuan.org/merged) || continue; key=$(v111_bootstrap_deb_keyring devuan "$suite" "$mirror") && ui_msg 'Devuan keyring ready' "$key";;
      list) ui_text 'Cached RootFS keyrings' "$(v111_cached_keyrings_report)";;
      clear) v111_clear_keyring_cache;;
      back) return 0;;
    esac
  done
}
