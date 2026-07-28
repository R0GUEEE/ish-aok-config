# Repository & Package Policy API — v8.6.0

The v8.6 layer provides advisory repository audits and explicit package-policy operations for an active RootFS.

## API

- `repo_v86_manager ROOT`
- `repo_v86_files ROOT`
- `repo_v86_audit ROOT`
- `repo_v86_policy_report ROOT`
- `repo_v86_hold ROOT PACKAGE`
- `repo_v86_snapshot ROOT`
- `repo_v86_report ROOT`

The scanner flags explicit insecure settings but does not claim that every repository is cryptographically verified. Native package-manager refresh remains the authoritative metadata/signature validation step.
