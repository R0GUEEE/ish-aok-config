#!/bin/sh
backend_prepare(){ return 0; }
backend_keyrings(){ return 0; }
backend_configure(){ return 0; }
backend_cleanup(){ return 0; }
backend_verify(){
  dest=$(v1110_profile DEST)
  [ -d "$dest" ] || [ "${V1110_DRY_RUN:-0}" = 1 ]
}
backend_package(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && return 0
  dest=$(v1110_profile DEST); [ -d "$dest" ] || return 1
  archive=$(v1101_profile_value ARTIFACT 2>/dev/null || true)
  [ -n "$archive" ] || return 0
  tar -C "$dest" -cf "$archive" .
}
