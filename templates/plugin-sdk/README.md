# iSH-AOK plugin template

Edit `plugin.conf`, implement handlers in `module.sh`, then install the directory from **Module and Plugin SDK**.

Manifest fields:
- `id`: stable identifier using letters, digits, dots, dashes, or underscores
- `title`, `category`, `version`, `description`
- `entry`: relative shell entry file
- `requires`: comma-separated capabilities (`rootfs`, `root`, `network`, `package-manager`, `command:NAME`, `distro:ID`, `arch:ARCH`, `init:NAME`)
- `actions`: comma-separated `action_id:handler:Title` records
