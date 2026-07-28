#!/bin/sh
# v9.5 simplified navigation helpers.
v95_builder_capabilities_ui(){ ui_text 'Builder capabilities' "$(v94_capability_report)"; }
v95_menu_report(){
  printf '%s %s — Simplified Navigation\n\n' "$PROGRAM" "$VERSION"
  printf 'Primary workspace entries: %s\n' "$(grep -cv '^#\|^$' "$V91_MENU_DIR/workspace.menu" 2>/dev/null || echo 0)"
  printf 'RootFS primary entries: %s\n' "$(grep -cv '^#\|^$' "$V91_MENU_DIR/rootfs.menu" 2>/dev/null || echo 0)"
  printf 'Build primary entries: %s\n' "$(grep -cv '^#\|^$' "$V91_MENU_DIR/build.menu" 2>/dev/null || echo 0)"
  printf 'Classic navigation: preserved\n'
}
