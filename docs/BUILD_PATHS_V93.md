# v9.3 Build Sources and Artifacts

v9.3 centralizes three independent paths used by RootFS builds:

1. **Source** — repository mirror, archive, directory, or native backend defaults.
2. **RootFS destination** — managed by the v9.2 location selector.
3. **Artifact directory** — where optional tar archives are written.

New profile keys:

- `SOURCE_TYPE=repository|archive|directory|native`
- `SOURCE_VALUE=<URL-or-path>`
- `ARTIFACT_DIR=/AOK/build-artifacts`
- `CREATE_ARCHIVE=yes|no`

Existing `MIRROR`, `DEST`, and `COMPRESSION` keys remain compatible.
