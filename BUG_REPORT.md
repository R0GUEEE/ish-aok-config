# iSH-AOK Config v11.3.2 Project Audit

## Fixed defects

### 1. Incorrect application version
`lib/core.sh` still reported `11.3.0` after the v11.3.1 maintenance release.

**Fix:** bumped the maintenance release to `11.3.2` and synchronized the SDK core-version value.

### 2. Broken main-menu status formatting
The active v11 main menu passed `\\n` as literal text, so text-mode interfaces displayed `\\nActive RootFS` rather than a new line.

**Fix:** construct the status block with `printf`, producing a real newline across dialog, whiptail, and text interfaces.

### 3. Incomplete command-line help
Several implemented v11 commands were absent from `--help`.

**Fix:** replaced the compressed legacy usage string with categorized help covering current reports, audits, actions, and operating modes.

### 4. Unknown command-line options opened the TUI
Misspelled or unsupported options silently fell through to `main_menu`.

**Fix:** unknown options and unexpected positional arguments now print a diagnostic and return exit status 2. An empty argument list still opens the TUI.

### 5. Missing version command
There was no stable non-interactive way to query the installed release.

**Fix:** added `--version`.

### 6. Missing SDK self-test dispatch and implementation
The intended SDK self-test was not available as a CLI operation. An initial dispatch exposed that no implementation existed.

**Fix:** added `v112_sdk_self_test` and `--sdk-self-test`. It validates every built-in and user plugin manifest and entry script, then verifies plugin indexing.

### 7. Legacy example plugin failed the current SDK schema
`plugins/modules/example/plugin.conf` used the obsolete keys `entrypoint` and `minimum_core`, while the current SDK requires `entry` and `min_core_version`.

**Fix:** migrated the manifest without changing its plugin ID or compatibility-facing version.

### 8. Diagnostics audit was not exposed through the CLI
The integrated audit existed only as an internal/menu function.

**Fix:** added `--diagnostics-audit`.

## Validation

- POSIX shell syntax scan: PASS
- Menu route audit: PASS
- Full menu audit: PASS
- Duplicate menu audit: PASS
- Software catalog handler audit: PASS
- SDK plugin self-test: PASS
- Isolated regression suite: 68 passed, 0 failed, 0 timed out

## Test execution note

The legacy aggregate test runner can retain inherited descriptors in some harnesses after printing its summary. Release validation therefore also runs every test in an isolated process with stdin detached and a per-test timeout. All 68 tests exit normally under that method.
