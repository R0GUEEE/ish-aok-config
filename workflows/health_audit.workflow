meta	name	RootFS Health Audit
meta	description	Validate the active RootFS and retain health and compatibility reports
step	refresh	Refresh RootFS metadata	workflow_task_refresh	{{ACTIVE_ROOTFS}}	rootfs			
step	health	Generate health report	workflow_task_health		rootfs			{{REPORT_DIR}}
step	compat	Generate compatibility report	workflow_task_compatibility		rootfs			{{REPORT_DIR}}
