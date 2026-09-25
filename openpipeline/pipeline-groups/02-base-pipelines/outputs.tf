# These two outputs are the contract between this stack and the app stack.
# See ../03-app-pipelines/terraform.tfvars.example for how to consume them.

output "pre_member_base_pipeline_id" {
  description = "Settings object ID of the base pipeline that runs before member pipelines."
  value       = dynatrace_openpipeline_v2_logs_pipelines.pre_member.id
}

output "post_member_base_pipeline_id" {
  description = "Settings object ID of the base pipeline that runs after member pipelines."
  value       = dynatrace_openpipeline_v2_logs_pipelines.post_member.id
}
