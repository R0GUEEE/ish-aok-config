# Registry and catalog architecture

Catalog format:

```text
id|label|description|handler|flags
```

Built-in catalogs:

- `centers.tsv`: top-level functional centers.
- `profiles.tsv`: reusable system profiles.
- `themes.tsv`: coordinated theme presets.
- `plugin-marketplace.tsv`: marketplace actions.

Handlers are POSIX shell functions loaded from `modules/`. Catalogs intentionally contain data only; privileged or destructive behavior remains in reviewed shell functions with confirmation, backup, logging, dry-run, and progress support.

The 6.0 layer is additive. Existing 5.x menus, adapters, manifests, templates, state directories, and profiles remain usable.
