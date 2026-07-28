# iSH-AOK Config v9.1 Modular Core

v9.1 preserves the existing POSIX shell modules and public dispatcher actions while moving workspace navigation into declarative `menus/*.menu` files.

## Core boundaries

- `lib/`: runtime APIs, UI, registry, cache, workflow and SDK support.
- `modules/`: feature implementations and compatibility wrappers.
- `menus/`: declarative navigation definitions.
- `config/`: grouped application defaults.
- `tests/`: legacy regression tests plus unit, integration and portability groups.
- `extensions/`: dynamically discovered modules.

## Menu format

```text
id|label|handler|description
```

Handlers may be shell functions, `@menu:name`, `@action:id`, or `@return`.

## Compatibility

The classic v8 navigation, existing function names, command action IDs, profiles, workflows, recipes and state files are retained.
