#!/bin/sh

v84_show_active_report(){
  root=$(active_rootfs 2>/dev/null || echo /)
  [ -d "$root" ] || root=/
  out=$(v84_distribution_report "$root") || { ui_msg Error 'Unable to generate distribution report.'; return 1; }
  ui_text 'Distribution integration report' "$(cat "$out")"
}

v84_show_host_report(){
  out=$(v84_distribution_report /) || return
  ui_text 'Host distribution report' "$(cat "$out")"
}

v84_profiles_view(){ ui_text 'Supported distribution profiles' "$(v84_profile_table | sed 's/\\t/  /g')"; }

v84_service_capabilities(){
  root=$(active_rootfs 2>/dev/null || echo /); [ -d "$root" ] || root=/
  init=$(v84_detect_init "$root")
  text="Detected init: $init\n\n"
  case $init in
    sysv) text="${text}Commands: service, update-rc.d, invoke-rc.d\nService scripts: /etc/init.d";;
    openrc) text="${text}Commands: rc-service, rc-update\nRunlevels: /etc/runlevels";;
    runit) text="${text}Commands: sv\nDefinitions: /etc/sv\nEnabled services: /var/service";;
    systemd) text="${text}systemd is not a native iSH-AOK service target. Use compatibility audits and init conversion tools.";;
    *) text="${text}No supported service manager was detected.";;
  esac
  ui_text 'Service capability profile' "$text"
}

v84_package_capabilities(){
  root=$(active_rootfs 2>/dev/null || echo /); [ -d "$root" ] || root=/
  pkg=$(v84_detect_package_manager "$root")
  ui_text 'Package capability profile' "Detected package manager: $pkg\n\nUnified operations:\nrefresh\nsearch\ninstall\nremove\nupgrade\npackage info\ninstalled inventory\norphan inventory"
}

v84_distribution_integration_menu(){
  while :; do
    c=$(ui_menu 'Distribution integration' 'Normalized capability profiles for hosts and RootFS environments.' \
      active 'Active RootFS compatibility report' \
      host 'Host compatibility report' \
      profiles 'Supported distribution profiles' \
      packages 'Package-manager capabilities' \
      services 'Init and service capabilities' \
      init 'Open init conversion tools' \
      repos 'Open repository configuration' \
      repair 'Open architecture and package repair') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      active) v84_show_active_report;;
      host) v84_show_host_report;;
      profiles) v84_profiles_view;;
      packages) v84_package_capabilities;;
      services) v84_service_capabilities;;
      init) init_system_menu;;
      repos) repositories_menu;;
      repair) aok_arch_package_repair_menu 2>/dev/null || recovery_center;;
    esac
  done
}
