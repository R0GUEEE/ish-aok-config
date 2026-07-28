# v11.0.1 RootFS Builder Framework

This milestone turns the RootFS Builder into a metadata-driven build pipeline while retaining the existing v10 execution backends.

## Components

- Reusable build profiles under `data/v11/profiles/`.
- Distribution-aware package sets under `data/v11/package-sets/`.
- Builder-only repository and mirror settings.
- Cache namespaces for keyrings, packages, metadata, mirrors, bootstrap data, and artifacts.
- Pre-build validation with release-blocking failures.
- Queue job records containing complete build-profile snapshots.
- Post-build filesystem validation.
- Reproducibility manifests with package, source, target, validation, artifact, and checksum data.

## Cache layout

The default cache root is `/var/cache/ish-aok-config`:

```
keyrings/
packages/
metadata/
mirrors/
bootstrap/
artifacts/
```

Set `ISH_AOK_CACHE_ROOT` to relocate it.

## Compatibility

The framework is POSIX shell and uses existing iSH-AOK-compatible builders. It does not require systemd and keeps builder repository settings separate from host System Configuration.
