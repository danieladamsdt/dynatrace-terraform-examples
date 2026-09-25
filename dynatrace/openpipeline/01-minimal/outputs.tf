output "base_pipeline_id" {
  description = "Settings object ID of the base pipeline."
  value       = dynatrace_openpipeline_v2_logs_pipelines.base.id
}

output "member_pipeline_id" {
  description = "Settings object ID of the member pipeline. Routing rules reference this."
  value       = dynatrace_openpipeline_v2_logs_pipelines.member.id
}

output "pipeline_group_id" {
  description = "Settings object ID of the pipeline group."
  value       = dynatrace_openpipeline_v2_logs_pipelinegroups.this.id
}
