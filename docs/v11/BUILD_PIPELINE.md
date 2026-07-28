# v11.1.0 Build Pipeline

The RootFS Builder is now a resumable stage engine. Each build receives an isolated workspace containing state, logs, profile snapshot, stage checkpoints, rootfs staging, cache, and artifacts.

Stages: initialize, plan, repository, keyrings, bootstrap, packages, configure, validate, package, cleanup.

Backends implement a stable interface: prepare, keyrings, bootstrap, install_packages, configure, verify, package, cleanup. Included backends are debootstrap, apk, pacstrap, dnf, xbps, stage3, and legacy.

Set `V1110_DRY_RUN=1` to validate the pipeline without changing a RootFS.
