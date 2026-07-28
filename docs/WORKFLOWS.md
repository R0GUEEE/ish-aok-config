# Workflow Engine

The v7.4 workflow engine executes ordered task pipelines using portable POSIX shell and tab-separated `.workflow` definitions.

## Definition format

Metadata records:

```text
meta<TAB>name<TAB>Display Name
meta<TAB>description<TAB>Description
```

Step records contain nine fields:

```text
step  id  title  handler  arguments  requirements  condition  rollback-targets  artifact
```

- `handler` is an already-loaded shell function.
- `arguments` supports `{{ACTIVE_ROOTFS}}`, `{{ROOTFS_ARCH}}`, `{{PACKAGE_MANAGER}}`, `{{INIT_SYSTEM}}`, `{{HOST_ARCH}}`, `{{BUILD_DATE}}`, `{{STATE_DIR}}`, and `{{REPORT_DIR}}`.
- `requirements` is comma separated. Supported values include `rootfs`, `root`, `network`, `dns`, `mounted-proc`, `mounted-dev`, `package-manager`, `command:NAME`, and `file:PATH`.
- `condition` uses `VARIABLE=value`.
- `rollback-targets` is a comma-separated list copied before the step executes.
- `artifact` is copied into the workflow run's artifact directory after success.

## State layout

```text
~/.local/state/ish-aok-config/workflows/
├── pipelines/
├── runs/
└── artifacts/
```

Each run contains metadata, a full log, per-step status, retained artifacts, and optional rollback data.

## CLI

```sh
./ish-aok-config --workflow-report
./ish-aok-config --workflow health_audit
```
