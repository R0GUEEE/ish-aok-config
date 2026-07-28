meta	name	Safe RootFS Cleanup
meta	description	Create an optimization report, safely clean caches, and run a health report
step	size	Generate size report	workflow_task_size_report		rootfs			{{REPORT_DIR}}
step	cleanup	Clean safe caches	workflow_task_cleanup		rootfs			
step	health	Verify RootFS health	workflow_task_health		rootfs			{{REPORT_DIR}}
