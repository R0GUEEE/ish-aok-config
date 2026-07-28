# v8.2 Architecture and Reliability

## Package adapter API

Use `pkg_refresh`, `pkg_search`, `pkg_install_packages`, `pkg_remove_packages`, `pkg_upgrade_packages`, `pkg_info`, `pkg_list_installed`, and `pkg_list_orphans`. The adapter detects APT, APK, Pacman, DNF/YUM, XBPS, Portage, or Zypper.

## RootFS API

Use `rootfs_api_mount`, `rootfs_api_unmount`, `rootfs_api_health`, `rootfs_api_snapshot`, `rootfs_api_archive`, `rootfs_api_diff`, and `rootfs_api_report` rather than duplicating RootFS path and context management.

## UI components

The v8.2 UI wrappers standardize status cards, searchable menus, checklists, tables, confirmations, and progress tasks while retaining dialog, whiptail, and text-mode compatibility.

## Cache

The cache is optional, flat-file based, TTL aware, and stored under the application state directory. It introduces no SQLite or daemon dependency.
