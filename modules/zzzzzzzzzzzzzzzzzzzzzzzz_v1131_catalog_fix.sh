#!/bin/sh
# v11.3.1: repaired data-driven software catalog.

v1131_catalog_item_menu(){
  _v1131_id=$1
  _v1131_label=$(v11_catalog_field "$_v1131_id" label)
  _v1131_description=$(v11_catalog_field "$_v1131_id" description)
  _v1131_handler=$(v11_catalog_field "$_v1131_id" handler)
  while :; do
    _v1131_choice=$(ui_menu "${_v1131_label:-Software}" "$_v1131_description\n\nRoute: ${_v1131_handler:-unavailable}" configure 'Install or configure' info 'Show catalog metadata' back Back) || return 0
    case $_v1131_choice in
      configure) v11_catalog_dispatch "$_v1131_id" || true;;
      info) ui_text "${_v1131_label:-Software}" "ID: $_v1131_id\nCategory: $(v11_catalog_field "$_v1131_id" category)\nDescription: $_v1131_description\nHandler: ${_v1131_handler:-none}\nCapability: $(v11_catalog_field "$_v1131_id" capability)";;
      back) return 0;;
    esac
  done
}

v1131_catalog_category_menu(){
  _v1131_category=$1
  while :; do
    set --
    while IFS='|' read -r _v1131_id _v1131_label _v1131_description _v1131_handler _v1131_capability; do
      [ -n "$_v1131_id" ] || continue
      if v11_catalog_handler_available "$_v1131_handler"; then _v1131_state=ready; else _v1131_state=unavailable; fi
      set -- "$@" "$_v1131_id" "[$_v1131_state] $_v1131_label — $_v1131_description"
    done <<EOF2
$(v11_catalog_items "$_v1131_category")
EOF2
    [ "$#" -gt 0 ] || { ui_msg 'Software Catalog' "No entries in $_v1131_category."; return 0; }
    _v1131_choice=$(ui_menu "Software Catalog: $_v1131_category" 'Select software to install or configure.' "$@" back Back) || return 0
    [ "$_v1131_choice" = back ] && return 0
    v1131_catalog_item_menu "$_v1131_choice"
  done
}

v1131_catalog_browse_menu(){
  while :; do
    set --
    while IFS= read -r _v1131_category; do
      [ -n "$_v1131_category" ] || continue
      _v1131_key=$(printf '%s' "$_v1131_category" | tr '[:upper:] ' '[:lower:]_')
      set -- "$@" "$_v1131_key" "$_v1131_category"
      eval "v1131_category_${_v1131_key}=\$_v1131_category"
    done <<EOF2
$(v11_catalog_categories)
EOF2
    _v1131_choice=$(ui_menu 'Software Catalog' 'Browse software by category. Entries are validated before they are opened.' "$@" report 'Flat catalog report' audit 'Audit catalog routes' back Back) || return 0
    case $_v1131_choice in
      report) ui_text 'Software Catalog' "$(v11_catalog_report)";;
      audit) ui_text 'Catalog Route Audit' "$(v11_catalog_audit 2>&1 || true)";;
      back) return 0;;
      *) eval "_v1131_category=\${v1131_category_${_v1131_choice}:-}"; [ -n "$_v1131_category" ] && v1131_catalog_category_menu "$_v1131_category";;
    esac
  done
}

v1100_software_catalog_menu(){
  while :; do
    _v1131_choice=$(ui_menu 'Software Catalog' 'Browse validated software entries or open package management tools.' browse 'Browse by category' packages 'Open package groups' installed 'Manage installed packages' search 'Search all actions' audit 'Audit catalog routes' back Back) || return 0
    case $_v1131_choice in
      browse) v1131_catalog_browse_menu;;
      packages) v105_package_groups_menu;;
      installed) package_menu;;
      search) v990_navigation_search_menu;;
      audit) ui_text 'Catalog Route Audit' "$(v11_catalog_audit 2>&1 || true)";;
      back) return 0;;
    esac
  done
}
