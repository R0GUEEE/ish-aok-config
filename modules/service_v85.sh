#!/bin/sh

v85_select_service(){
  r=$(active_rootfs 2>/dev/null || echo /); set --
  for s in $(service_v85_list "$r" 2>/dev/null); do
    if service_v85_enabled "$r" "$s"; then state=enabled; else state=disabled; fi
    set -- "$@" "$s" "$state"
  done
  [ "$#" -gt 0 ] || { ui_msg Services 'No services were discovered.'; return 1; }
  ui_menu 'Select service' "RootFS: $r | Init: $(service_v85_init "$r")" "$@"
}

v85_service_action(){
  action=$1; s=$(v85_select_service) || return; r=$(active_rootfs)
  case $action in
    enable) aok_confirm "Enable $s in $r?" && run_capture "Enable $s" service_v85_enable "$r" "$s";;
    disable) aok_confirm "Disable $s in $r?" && run_capture "Disable $s" service_v85_disable "$r" "$s";;
    status) run_capture "Status: $s" service_v85_status "$r" "$s";;
    start|stop|restart|reload) aok_confirm "$action $s in $r?" && run_capture "$action $s" service_v85_control "$r" "$s" "$action";;
  esac
}

v85_service_inventory(){
  r=$(active_rootfs 2>/dev/null || echo /); text=''
  for s in $(service_v85_list "$r" 2>/dev/null); do if service_v85_enabled "$r" "$s"; then state=enabled; else state=disabled; fi; text="$text\n$s  $state"; done
  [ -n "$text" ] || text='No services were discovered.'
  ui_text 'Service inventory' "RootFS: $r\nInit: $(service_v85_init "$r")\n$text"
}

v85_boot_report(){ out=$(service_v85_report "$(active_rootfs 2>/dev/null || echo /)") || { ui_msg Error 'Unable to create boot report.'; return 1; }; ui_text 'Boot and service audit' "$(cat "$out")"; }

v85_service_orchestration_menu(){
  while :; do
    c=$(ui_menu 'Service and Boot Orchestration' "Active: $(active_rootfs) | Init: $(service_v85_init "$(active_rootfs)")" \
      inventory 'List services and enabled state' \
      status 'Inspect service status' \
      start 'Start a service' \
      stop 'Stop a service' \
      restart 'Restart a service' \
      reload 'Reload a service' \
      enable 'Enable a service at boot' \
      disable 'Disable a service at boot' \
      audit 'Audit boot layout and broken links' \
      init 'Open init conversion and diagnostics') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      inventory) v85_service_inventory;; status|start|stop|restart|reload|enable|disable) v85_service_action "$c";; audit) v85_boot_report;; init) init_system_menu;;
    esac
  done
}
