# v11 Foundation

v11.0.0 milestone 1 introduces a stable foundation without removing v10.12 functionality.

## New contracts

- `data/v11/capabilities.tsv`: distribution feature matrix.
- `data/v11/software-catalog.tsv`: central software metadata.
- `data/v11/build-profiles.tsv`: builder profile metadata.
- `plugins/modules/<id>/plugin.conf`: discoverable module manifest.
- `lib/v11_foundation.sh`: POSIX metadata query API.

All files remain POSIX `sh` compatible and avoid systemd assumptions.
