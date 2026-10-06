output "frontend_id" {
  description = "Smartscape ID of the frontend (FRONTEND-…). The ID the Gen3 RUM API uses."
  value       = restapi_object.frontend.id
}

output "entity_id" {
  description = "Entity ID (APPLICATION-… or MOBILE_APPLICATION-…). The scope for the frontend's settings and the applicationId of its detection rules."
  value       = local.entity_id
}

output "frontend_name" {
  description = "The frontend.name value to filter on in DQL."
  value       = var.frontend_name
}

output "detection_rule_ids" {
  description = "Settings object IDs of the detection rules, keyed by list position."
  value       = { for k, r in dynatrace_application_detection_rule_v2.this : k => r.id }
}
