# v8.7 Builder and Menu Integration

v8.7 makes `RootFS Build Studio` the canonical entry point for all RootFS creation.

## Canonical routes

- Main menu → iSH-AOK and RootFS → Build Studio
- RootFS Studios → Build Studio
- v8 RootFS Platform → Build Studio and profiles
- Storage advanced tools → RootFS Build Studio

Legacy builder functions remain available as compatibility wrappers, but menus no longer present duplicate parallel builder hierarchies.

## Guided build profile

The Build Profile Wizard configures:

- distribution preset
- release and mirror
- architecture
- bootstrap backend
- destination
- package groups
- init system
- default shell
- locale, timezone, hostname and user
- SSH, sudo, DNS and registration features
- archive compression

The resulting profile remains a portable `KEY=value` file for automation and version control.
