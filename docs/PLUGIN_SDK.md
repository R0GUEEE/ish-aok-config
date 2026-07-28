# iSH-AOK Dynamic Module and Plugin SDK

## Discovery locations

- Built-ins: `extensions/`
- User plugins: `~/.local/share/ish-aok-config/plugins/`

A module uses `module.conf`; an installable plugin uses `plugin.conf`.

## Manifest

```ini
id=my_extension
title=My Extension
category=RootFS
version=1.0.0
description=Adds RootFS utilities.
entry=module.sh
requires=rootfs,command:tar
actions=inspect:my_inspect:Inspect RootFS
workflows=workflows/*.workflow
```

Requirements may use `rootfs`, `root`, `network`, `package-manager`, `command:NAME`, `file:PATH`, `distro:ID`, `arch:ARCH`, or `init:NAME`.

Action records use `action_id:handler:Title`. Multiple actions and workflow patterns are comma-separated.

## CLI

```sh
./ish-aok-config --module-report
./ish-aok-config --validate-modules
./ish-aok-config --run-action sdk
```

## Compatibility

The SDK is additive. Existing monolithic modules and menus continue to load. Extensions use POSIX shell and flat-file state, with no mandatory Python, SQLite, YAML parser, systemd, or daemon.
