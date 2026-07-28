meta	name	iSH-AOK Compatibility Check
meta	description	Run deep compatibility and boot/init audits
step	compat	Deep compatibility report	workflow_task_compatibility		rootfs			{{REPORT_DIR}}
step	boot	Boot and init report	workflow_task_boot_report		rootfs			{{REPORT_DIR}}
