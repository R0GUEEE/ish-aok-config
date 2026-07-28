# Architecture

The launcher sources `lib/*.sh`, package adapters, service adapters, then feature modules. Modules share only the public helpers in `lib/`.

New package managers belong in `modules/package/`. New init systems belong in `modules/services/`. New feature areas belong in `modules/` and should expose one top-level `*_menu` function.
