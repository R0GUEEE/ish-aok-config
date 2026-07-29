#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ISH_AOK_CONFIG_ROOT=$BASE HOME=${TMPDIR:-/tmp}/ish-aok-v1180-home.$$ XDG_STATE_HOME=$HOME/state
mkdir -p "$HOME"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done

for fn in v1100_software_catalog_menu v1180_featured_menu v1180_categories_menu v1180_search_menu v1180_installed_menu v1180_updates_menu v1180_catalog_item_menu v1180_native_package_menu; do
  command -v "$fn" >/dev/null
done

PKG_MGR=apt
[ "$(v1180_catalog_package fd)" = fd-find ]
[ "$(v1180_catalog_package openssh-server)" = openssh-server ]
PKG_MGR=apk
[ "$(v1180_catalog_package openssh-server)" = openssh ]
[ "$(v1180_catalog_package bind-tools)" = bind-tools ]
PKG_MGR=pacman
[ "$(v1180_catalog_package sqlite)" = sqlite ]
[ "$(v1180_catalog_total)" -ge 50 ]

CATALOG=$BASE/modules/zzzzzzzzzzzzzzzzzzzzzzzzzzzzz_v1180_discover_catalog.sh
grep -q "featured 'Featured software'" "$CATALOG"
grep -q "categories 'Browse categories'" "$CATALOG"
grep -q "search 'Search software'" "$CATALOG"
grep -q "installed 'Installed software'" "$CATALOG"
grep -q "updates 'Software updates'" "$CATALOG"
grep -q "sources 'Software sources and repositories'" "$CATALOG"
sh -n "$CATALOG"

rm -rf "$HOME"
printf 'v11.8 Discover-style software catalog: PASS\n'
