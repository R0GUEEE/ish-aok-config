# iSH-AOK Config Plugin SDK 11.2

Plugins are directories containing `plugin.yaml` and a POSIX shell entry file.

Required manifest fields:

- `id`
- `name`
- `version`
- `entry`
- `min_core_version`

Optional fields include `author`, `category`, `dependencies`, `hooks`, `capabilities`, and `description`.

The entry file must pass `sh -n` and should expose only prefixed functions. Plugins may implement lifecycle callbacks such as `plugin_startup`, `plugin_pre_build`, and `plugin_post_build`.

User plugins are installed below `${XDG_DATA_HOME:-$HOME/.local/share}/ish-aok-config/plugins` and never overwrite the project core.

Distribution SDK definitions contain `metadata.conf`, `repositories.conf`, `keyrings.conf`, `packages.conf`, `backend.sh`, and `validation.sh`. Backend files must export `backend_prepare`, `backend_bootstrap`, `backend_install_packages`, `backend_verify`, and `backend_cleanup`.
