#!/bin/sh
# v11.8.0: app-store-style software discovery for portable iSH-AOK systems.

v1180_catalog_package(){
  _v1180_id=$1
  _v1180_spec=$(v11_catalog_field "$_v1180_id" packages)
  [ -n "$_v1180_spec" ] || { printf '%s\n' "$_v1180_id"; return; }
  _v1180_manager=$(pkg_api_manager 2>/dev/null || printf '%s' "${PKG_MGR:-unknown}")
  awk -v spec="$_v1180_spec" -v manager="$_v1180_manager" 'BEGIN {
    count=split(spec, entries, ";"); fallback=""
    for (i=1; i<=count; i++) {
      split(entries[i], pair, "=")
      if (pair[1]=="default") fallback=pair[2]
      if (pair[1]==manager) { print pair[2]; exit }
    }
    if (fallback!="") print fallback
  }'
}

v1180_package_installed(){
  _v1180_package=$1
  [ -n "$_v1180_package" ] || return 1
  if command -v v105_pkg_installed >/dev/null 2>&1; then
    v105_pkg_installed "$_v1180_package"
  else
    package_installed "$_v1180_package"
  fi
}

v1180_catalog_installed(){
  _v1180_package=$(v1180_catalog_package "$1")
  v1180_package_installed "$_v1180_package"
}

v1180_catalog_status(){
  if v1180_catalog_installed "$1"; then printf 'Installed'; else printf 'Not installed'; fi
}

v1180_catalog_total(){
  awk -F '|' '$1 !~ /^#/ && NF >= 8 {count++} END {print count+0}' "$V11_SOFTWARE_CATALOG"
}

v1180_catalog_installed_total(){
  _v1180_count=0
  while IFS='|' read -r _v1180_id _v1180_rest; do
    case $_v1180_id in ''|\#*) continue;; esac
    v1180_catalog_installed "$_v1180_id" && _v1180_count=$((_v1180_count + 1))
  done < "$V11_SOFTWARE_CATALOG"
  printf '%s\n' "$_v1180_count"
}

v1180_package_install(){
  _v1180_package=$1 _v1180_label=$2
  ui_yesno "Install $_v1180_label" "Install native package $_v1180_package using ${PKG_MGR:-the detected package manager}?" || return 0
  if command -v v104_main_scope_call >/dev/null 2>&1; then
    v104_main_scope_call pkg_install "$_v1180_package"
  else
    pkg_install_packages "$_v1180_package"
  fi
}

v1180_package_remove(){
  _v1180_package=$1 _v1180_label=$2
  ui_yesno "Remove $_v1180_label" "Remove native package $_v1180_package? Dependencies required by other software are left to the native package manager." || return 0
  if command -v v104_main_scope_call >/dev/null 2>&1; then
    v104_main_scope_call pkg_remove "$_v1180_package"
  else
    pkg_remove_packages "$_v1180_package"
  fi
}

v1180_package_information(){
  _v1180_package=$1 _v1180_label=$2
  _v1180_info_file="$TMP_DIR/catalog-package-info.$$"
  pkg_info "$_v1180_package" >"$_v1180_info_file" 2>&1 || true
  [ -s "$_v1180_info_file" ] || printf 'No repository metadata is available for %s.\n' "$_v1180_package" >"$_v1180_info_file"
  ui_text "$_v1180_label — package information" "$(sed -n '1,180p' "$_v1180_info_file")"
  rm -f "$_v1180_info_file"
}

v1180_catalog_item_menu(){
  _v1180_id=$1
  _v1180_label=$(v11_catalog_field "$_v1180_id" label)
  _v1180_category=$(v11_catalog_field "$_v1180_id" category)
  _v1180_description=$(v11_catalog_field "$_v1180_id" description)
  _v1180_handler=$(v11_catalog_field "$_v1180_id" handler)
  _v1180_package=$(v1180_catalog_package "$_v1180_id")
  while :; do
    if v1180_package_installed "$_v1180_package"; then
      _v1180_status=Installed
      set -- remove 'Remove from this system'
    else
      _v1180_status='Not installed'
      set -- install 'Install on this system'
    fi
    set -- "$@" package_info 'Native package information'
    v11_catalog_handler_available "$_v1180_handler" && set -- "$@" configure 'Open configuration tools'
    _v1180_choice=$(ui_menu "${_v1180_label:-Software}" "$_v1180_description\n\nStatus: $_v1180_status\nCategory: $_v1180_category\nNative package: $_v1180_package\nPackage manager: ${PKG_MGR:-unknown}" "$@") || return 0
    case $_v1180_choice in
      install) v1180_package_install "$_v1180_package" "$_v1180_label" || true;;
      remove) v1180_package_remove "$_v1180_package" "$_v1180_label" || true;;
      package_info) v1180_package_information "$_v1180_package" "$_v1180_label";;
      configure) "$_v1180_handler" || true;;
    esac
  done
}

v1180_native_package_menu(){
  _v1180_package=$1
  [ -n "$_v1180_package" ] || return 0
  while :; do
    if v1180_package_installed "$_v1180_package"; then
      _v1180_status=Installed; set -- remove 'Remove from this system'
    else
      _v1180_status='Not installed'; set -- install 'Install on this system'
    fi
    set -- "$@" package_info 'Show repository information'
    _v1180_choice=$(ui_menu "$_v1180_package" "Native repository package\n\nStatus: $_v1180_status\nPackage manager: ${PKG_MGR:-unknown}" "$@") || return 0
    case $_v1180_choice in
      install) v1180_package_install "$_v1180_package" "$_v1180_package" || true;;
      remove) v1180_package_remove "$_v1180_package" "$_v1180_package" || true;;
      package_info) v1180_package_information "$_v1180_package" "$_v1180_package";;
    esac
  done
}

v1180_catalog_list_menu(){
  _v1180_title=$1 _v1180_message=$2 _v1180_ids_file=$3
  while :; do
    set --
    while IFS= read -r _v1180_id; do
      [ -n "$_v1180_id" ] || continue
      _v1180_label=$(v11_catalog_field "$_v1180_id" label)
      _v1180_description=$(v11_catalog_field "$_v1180_id" description)
      _v1180_status=$(v1180_catalog_status "$_v1180_id")
      set -- "$@" "$_v1180_id" "[$_v1180_status] $_v1180_label — $_v1180_description"
    done < "$_v1180_ids_file"
    [ "$#" -gt 0 ] || { ui_msg "$_v1180_title" 'No matching catalog entries were found.'; return 0; }
    _v1180_choice=$(ui_menu "$_v1180_title" "$_v1180_message" "$@") || return 0
    v1180_catalog_item_menu "$_v1180_choice"
  done
}

v1180_featured_menu(){
  _v1180_featured_file="$TMP_DIR/catalog-featured.$$"
  awk -F '|' '$1 !~ /^#/ && $7=="yes" {print $1}' "$V11_SOFTWARE_CATALOG" >"$_v1180_featured_file"
  v1180_catalog_list_menu 'Featured Software' 'Recommended, lightweight software that works well in iSH-AOK filesystems.' "$_v1180_featured_file"
  rm -f "$_v1180_featured_file"
}

v1180_category_menu(){
  _v1180_category=$1
  _v1180_category_file="$TMP_DIR/catalog-category.$$"
  awk -F '|' -v category="$_v1180_category" '$1 !~ /^#/ && $2==category {print $1}' "$V11_SOFTWARE_CATALOG" >"$_v1180_category_file"
  v1180_catalog_list_menu "$_v1180_category" 'Select software to see details, install it, remove it, or open its configuration tools.' "$_v1180_category_file"
  rm -f "$_v1180_category_file"
}

v1180_categories_menu(){
  _v1180_categories_file="$TMP_DIR/catalog-categories.$$"
  awk -F '|' '$1 !~ /^#/ {count[$2]++} END {for (category in count) print category "|" count[category]}' "$V11_SOFTWARE_CATALOG" | sort >"$_v1180_categories_file"
  while :; do
    set --; _v1180_index=0
    while IFS='|' read -r _v1180_category _v1180_count; do
      _v1180_index=$((_v1180_index + 1)); set -- "$@" "category_$_v1180_index" "$_v1180_category — $_v1180_count applications"
    done < "$_v1180_categories_file"
    _v1180_choice=$(ui_menu 'Software Categories' 'Browse the catalog by purpose.' "$@") || { rm -f "$_v1180_categories_file"; return 0; }
    _v1180_index=${_v1180_choice#category_}
    _v1180_category=$(sed -n "${_v1180_index}s/|.*//p" "$_v1180_categories_file")
    [ -n "$_v1180_category" ] && v1180_category_menu "$_v1180_category"
  done
}

v1180_native_search(){
  _v1180_query=$1
  _v1180_native_file="$TMP_DIR/catalog-native-search.$$"
  pkg_search "$_v1180_query" >"$_v1180_native_file" 2>&1 || true
  [ -s "$_v1180_native_file" ] || { ui_msg 'Repository Search' "No native repository results were found for $_v1180_query."; rm -f "$_v1180_native_file"; return 0; }
  ui_text 'Repository Search' "$(sed -n '1,160p' "$_v1180_native_file")"
  _v1180_package=$(ui_input 'Open Package' 'Enter an exact native package name to view or install, or leave blank to return:' '') || { rm -f "$_v1180_native_file"; return 0; }
  rm -f "$_v1180_native_file"
  [ -n "$_v1180_package" ] && v1180_native_package_menu "$_v1180_package"
}

v1180_search_menu(){
  _v1180_query=$(ui_input 'Search Software' 'Search names, descriptions, and categories:' '') || return 0
  [ -n "$_v1180_query" ] || return 0
  _v1180_search_file="$TMP_DIR/catalog-search.$$"
  awk -F '|' -v query="$_v1180_query" 'BEGIN {query=tolower(query)} $1 !~ /^#/ {text=tolower($1 " " $2 " " $3 " " $4); if (index(text,query)) print $1}' "$V11_SOFTWARE_CATALOG" >"$_v1180_search_file"
  while :; do
    set --
    while IFS= read -r _v1180_id; do
      [ -n "$_v1180_id" ] || continue
      _v1180_label=$(v11_catalog_field "$_v1180_id" label)
      _v1180_status=$(v1180_catalog_status "$_v1180_id")
      set -- "$@" "$_v1180_id" "[$_v1180_status] $_v1180_label — $(v11_catalog_field "$_v1180_id" description)"
    done < "$_v1180_search_file"
    set -- "$@" native_search "Search all ${PKG_MGR:-native} repository packages for ‘$_v1180_query’"
    _v1180_choice=$(ui_menu 'Search Results' 'Catalog matches appear first. Repository Search covers software not yet curated here.' "$@") || { rm -f "$_v1180_search_file"; return 0; }
    case $_v1180_choice in native_search) v1180_native_search "$_v1180_query";; *) v1180_catalog_item_menu "$_v1180_choice";; esac
  done
}

v1180_installed_menu(){
  _v1180_installed_file="$TMP_DIR/catalog-installed.$$"
  : >"$_v1180_installed_file"
  while IFS='|' read -r _v1180_id _v1180_rest; do
    case $_v1180_id in ''|\#*) continue;; esac
    v1180_catalog_installed "$_v1180_id" && printf '%s\n' "$_v1180_id" >>"$_v1180_installed_file"
  done < "$V11_SOFTWARE_CATALOG"
  while :; do
    set --
    while IFS= read -r _v1180_id; do
      [ -n "$_v1180_id" ] || continue
      set -- "$@" "$_v1180_id" "$(v11_catalog_field "$_v1180_id" label) — $(v1180_catalog_package "$_v1180_id")"
    done < "$_v1180_installed_file"
    set -- "$@" inventory 'Show every installed native package'
    _v1180_choice=$(ui_menu 'Installed Software' 'Curated applications installed on this system. Open one to inspect or remove it.' "$@") || { rm -f "$_v1180_installed_file"; return 0; }
    if [ "$_v1180_choice" = inventory ]; then
      _v1180_inventory="$TMP_DIR/catalog-installed-all.$$"; pkg_list_installed >"$_v1180_inventory" 2>&1 || true
      ui_text 'All Installed Packages' "$(sed -n '1,500p' "$_v1180_inventory")"; rm -f "$_v1180_inventory"
    else
      v1180_catalog_item_menu "$_v1180_choice"
    fi
  done
}

v1180_updates_preview(){
  _v1180_updates_file="$TMP_DIR/catalog-updates.$$"
  _v1180_manager=$(pkg_api_manager 2>/dev/null || printf unknown)
  case $_v1180_manager in
    apt) apt list --upgradable >"$_v1180_updates_file" 2>&1 || true;;
    apk) apk version -l '<' >"$_v1180_updates_file" 2>&1 || true;;
    pacman) { command -v checkupdates >/dev/null 2>&1 && checkupdates || pacman -Qu; } >"$_v1180_updates_file" 2>&1 || true;;
    dnf|yum) "$_v1180_manager" check-update >"$_v1180_updates_file" 2>&1 || true;;
    xbps) xbps-install -Mun >"$_v1180_updates_file" 2>&1 || true;;
    emerge) emerge -puDN @world >"$_v1180_updates_file" 2>&1 || true;;
    zypper) zypper list-updates >"$_v1180_updates_file" 2>&1 || true;;
    *) printf 'Update preview is unavailable because no supported native package manager was detected.\n' >"$_v1180_updates_file";;
  esac
  ui_text 'Available Updates' "$(sed -n '1,300p' "$_v1180_updates_file")"
  rm -f "$_v1180_updates_file"
}

v1180_updates_menu(){
  while :; do
    _v1180_choice=$(ui_menu 'Software Updates' "Native package manager: ${PKG_MGR:-unknown}" preview 'View available updates' refresh 'Refresh software sources' upgrade 'Install all available updates') || return 0
    case $_v1180_choice in
      preview) v1180_updates_preview;;
      refresh) v104_main_scope_call pkg_update || true;;
      upgrade) ui_yesno 'Install Updates' 'Upgrade all installed packages using the native package manager?' && v104_main_scope_call pkg_upgrade || true;;
    esac
  done
}

# Compatibility names now open the richer catalog views.
v1131_catalog_item_menu(){ v1180_catalog_item_menu "$@"; }
v1131_catalog_category_menu(){ v1180_category_menu "$@"; }
v1131_catalog_browse_menu(){ v1180_categories_menu; }

v1100_software_catalog_menu(){
  while :; do
    _v1180_total=$(v1180_catalog_total)
    _v1180_installed=$(v1180_catalog_installed_total)
    _v1180_choice=$(ui_menu 'Software Catalog' "Discover software for this iSH-AOK system.\n\n${PKG_MGR:-Native} packages | $_v1180_total curated | $_v1180_installed installed" \
      featured 'Featured software' \
      categories 'Browse categories' \
      search 'Search software' \
      installed 'Installed software' \
      updates 'Software updates' \
      groups 'Package presets and groups' \
      sources 'Software sources and repositories') || return 0
    case $_v1180_choice in
      featured) v1180_featured_menu;;
      categories) v1180_categories_menu;;
      search) v1180_search_menu;;
      installed) v1180_installed_menu;;
      updates) v1180_updates_menu;;
      groups) v105_package_groups_menu;;
      sources) v108_repository_sources_menu;;
    esac
  done
}
