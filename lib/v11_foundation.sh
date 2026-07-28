#!/bin/sh
# v11 foundation: centralized capability and catalog metadata.

V11_DATA_DIR=${V11_DATA_DIR:-$ISH_AOK_CONFIG_ROOT/data/v11}
V11_CAPABILITIES=${V11_CAPABILITIES:-$V11_DATA_DIR/capabilities.tsv}
V11_SOFTWARE_CATALOG=${V11_SOFTWARE_CATALOG:-$V11_DATA_DIR/software-catalog.tsv}
V11_BUILD_PROFILES=${V11_BUILD_PROFILES:-$V11_DATA_DIR/build-profiles.tsv}
V11_PLUGIN_DIR=${V11_PLUGIN_DIR:-$ISH_AOK_CONFIG_ROOT/plugins/modules}

v11_normalize_distro(){
  case ${1:-${DISTRO_ID:-unknown}} in
    devuan*) printf devuan;; debian*) printf debian;; ubuntu*) printf ubuntu;;
    alpine*) printf alpine;; arch*|manjaro*) printf arch;; fedora*|rhel*|centos*) printf fedora;;
    void*) printf void;; gentoo*) printf gentoo;; *) printf unknown;;
  esac
}

v11_capability_value(){
  capability=$1; distro=$(v11_normalize_distro "${2:-${DISTRO_ID:-unknown}}")
  case $distro in devuan) col=2;; debian) col=3;; ubuntu) col=4;; alpine) col=5;; arch) col=6;; fedora) col=7;; void) col=8;; gentoo) col=9;; *) printf no; return 1;; esac
  awk -F '|' -v key="$capability" -v col="$col" '$1==key {print $col; found=1; exit} END{if(!found) exit 1}' "$V11_CAPABILITIES"
}

v11_supports(){
  value=$(v11_capability_value "$1" "${2:-${DISTRO_ID:-unknown}}" 2>/dev/null || printf no)
  [ "$value" = yes ] || [ "$value" = optional ]
}

v11_capability_report(){
  distro=$(v11_normalize_distro "${1:-${DISTRO_ID:-unknown}}")
  printf 'Capability report for %s\n\n' "$distro"
  awk -F '|' -v distro="$distro" '
    BEGIN { cols["devuan"]=2; cols["debian"]=3; cols["ubuntu"]=4; cols["alpine"]=5; cols["arch"]=6; cols["fedora"]=7; cols["void"]=8; cols["gentoo"]=9; c=cols[distro] }
    $1 !~ /^#/ && NF >= 10 { printf "%-24s %-10s %s\n", $1, $c, $10 }
  ' "$V11_CAPABILITIES"
}

v11_catalog_report(){
  awk -F '|' '$1 !~ /^#/ && NF >= 6 {printf "%-14s %-12s %-20s %s\n", $1, $2, $3, $4}' "$V11_SOFTWARE_CATALOG"
}

v11_plugin_inventory(){
  count=0
  for manifest in "$V11_PLUGIN_DIR"/*/plugin.conf; do
    [ -f "$manifest" ] || continue
    id=$(sed -n 's/^id=//p' "$manifest" | head -n1)
    name=$(sed -n 's/^name=//p' "$manifest" | head -n1)
    version=$(sed -n 's/^version=//p' "$manifest" | head -n1)
    status=$(sed -n 's/^enabled=//p' "$manifest" | head -n1)
    printf '%s|%s|%s|%s|%s\n' "$id" "$name" "$version" "${status:-yes}" "$manifest"
    count=$((count + 1))
  done
  [ "$count" -gt 0 ]
}

v11_build_profile_get(){
  id=$1; field=$2
  case $field in id) col=1;; label) col=2;; description) col=3;; packages) col=4;; *) return 2;; esac
  awk -F '|' -v id="$id" -v col="$col" '$1==id {print $col; exit}' "$V11_BUILD_PROFILES"
}

# v11.3.1 catalog helpers. These intentionally validate all data-driven routes
# before dispatching so stale metadata cannot terminate the UI.
v11_catalog_categories(){
  awk -F '|' '$1 !~ /^#/ && NF >= 6 && !seen[$2]++ {print $2}' "$V11_SOFTWARE_CATALOG"
}

v11_catalog_items(){
  _v11_category=${1:-}
  awk -F '|' -v category="$_v11_category" '$1 !~ /^#/ && NF >= 6 && (category=="" || $2==category) {print $1 "|" $3 "|" $4 "|" $5 "|" $6}' "$V11_SOFTWARE_CATALOG"
}

v11_catalog_field(){
  _v11_id=$1 _v11_field=$2
  case $_v11_field in id) _v11_col=1;; category) _v11_col=2;; label) _v11_col=3;; description) _v11_col=4;; handler) _v11_col=5;; capability) _v11_col=6;; *) return 2;; esac
  awk -F '|' -v id="$_v11_id" -v col="$_v11_col" '$1==id {print $col; exit}' "$V11_SOFTWARE_CATALOG"
}

v11_catalog_handler_available(){
  _v11_handler=$1
  [ -n "$_v11_handler" ] && command -v "$_v11_handler" >/dev/null 2>&1
}

v11_catalog_dispatch(){
  _v11_id=$1
  _v11_handler=$(v11_catalog_field "$_v11_id" handler)
  _v11_label=$(v11_catalog_field "$_v11_id" label)
  if v11_catalog_handler_available "$_v11_handler"; then
    "$_v11_handler"
  else
    ui_msg 'Software Catalog' "The configuration route for ${_v11_label:-$_v11_id} is unavailable.\n\nHandler: ${_v11_handler:-not configured}\n\nUse Package Groups or Search while this entry is repaired."
    return 1
  fi
}

v11_catalog_audit(){
  _v11_bad=0
  while IFS='|' read -r _v11_id _v11_category _v11_label _v11_description _v11_handler _v11_capability; do
    [ -n "$_v11_id" ] || continue
    case $_v11_id in \#*) continue;; esac
    if v11_catalog_handler_available "$_v11_handler"; then
      printf 'PASS | %-18s | %s\n' "$_v11_id" "$_v11_handler"
    else
      printf 'FAIL | %-18s | missing handler: %s\n' "$_v11_id" "${_v11_handler:-none}"
      _v11_bad=$((_v11_bad + 1))
    fi
  done < "$V11_SOFTWARE_CATALOG"
  [ "$_v11_bad" -eq 0 ]
}
