output "application_id" {
  description = "Entity ID of the configured frontend."
  value       = local.application_id
}

output "enablement_id" {
  description = "Settings object ID of the enablement object."
  value       = local.is_mobile ? one(dynatrace_mobile_app_enablement.this[*].id) : one(dynatrace_web_app_enablement.this[*].id)
}

output "extra_setting_ids" {
  description = "Settings object IDs of the extra settings, keyed by schema and list position."
  value       = { for k, s in dynatrace_generic_setting.extra : k => s.id }
}
