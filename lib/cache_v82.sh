#!/bin/sh
V82_CACHE_DIR=${V82_CACHE_DIR:-$STATE_DIR/cache-v82}
mkdir -p "$V82_CACHE_DIR" 2>/dev/null || true
cache_key(){ printf '%s' "$1" | cksum | awk '{print $1}'; }
cache_path(){ printf '%s/%s.cache\n' "$V82_CACHE_DIR" "$(cache_key "$1")"; }
cache_put(){ k=$1; ttl=${2:-300}; shift 2; f=$(cache_path "$k"); { printf 'expires=%s\n' "$(( $(date +%s) + ttl ))"; cat; } >"$f"; }
cache_get(){ f=$(cache_path "$1"); [ -f "$f" ] || return 1; exp=$(sed -n 's/^expires=//p' "$f" | head -n1); [ "${exp:-0}" -ge "$(date +%s)" ] 2>/dev/null || { rm -f "$f"; return 1; }; sed '1d' "$f"; }
cache_clear(){ rm -f "$V82_CACHE_DIR"/*.cache 2>/dev/null || true; }
