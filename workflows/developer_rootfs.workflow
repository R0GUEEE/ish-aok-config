meta	name	Developer RootFS Preparation
meta	description	Validate package tooling, open package setup, configure shell and create a report
step	health	Validate RootFS	workflow_task_health		rootfs			{{REPORT_DIR}}
step	packages	Open native package studio	rootfs_package_native		rootfs,package-manager			
step	shell	Configure shells and prompts	shell_center_v6					
step	report	Generate RootFS report	workflow_task_rootfs_report		rootfs			{{REPORT_DIR}}
