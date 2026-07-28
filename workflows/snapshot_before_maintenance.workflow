meta	name	Snapshot Before Maintenance
meta	description	Create a RootFS archive and manifest before maintenance
step	manifest	Create package and service manifest	workflow_task_manifest		rootfs			{{REPORT_DIR}}
step	snapshot	Create compressed RootFS archive	workflow_task_snapshot		rootfs,command:tar			
