output "frontend_id" {
  description = "Smartscape ID of the imported frontend (FRONTEND-…)."
  value       = restapi_object.frontend.id
}

output "entity_id" {
  description = "Entity ID of the imported frontend (APPLICATION-… or MOBILE_APPLICATION-…)."
  value       = local.entity_id
}

output "frontend_name" {
  description = "frontend.name of the imported frontend."
  value       = local.frontend_name
}

output "settings_applied" {
  description = "Number of settings objects applied from the bundle."
  value       = length(dynatrace_generic_setting.bundle)
}
