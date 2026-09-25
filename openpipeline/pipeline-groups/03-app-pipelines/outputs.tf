output "pipeline_group_id" {
  description = "Settings object ID of the pipeline group."
  value       = dynatrace_openpipeline_v2_logs_pipelinegroups.this.id
}

output "member_pipeline_ids" {
  description = "Map of application key to member pipeline settings object ID."
  value       = { for key, pipeline in dynatrace_openpipeline_v2_logs_pipelines.member : key => pipeline.id }
}

output "routing_evaluation_order" {
  description = "Application keys in the order their routing rules are evaluated. The catch-all runs after all of them."
  value       = local.app_keys_by_route_priority
}
