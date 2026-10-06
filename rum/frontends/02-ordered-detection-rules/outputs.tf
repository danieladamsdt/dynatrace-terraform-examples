output "entity_id" {
  description = "Entity ID (APPLICATION-…) the rules apply to."
  value       = local.entity_id
}

output "detection_rule_ids" {
  description = "Settings object IDs of the rules, in precedence order."
  value = compact([
    one(dynatrace_application_detection_rule_v2.slot_1[*].id),
    one(dynatrace_application_detection_rule_v2.slot_2[*].id),
    one(dynatrace_application_detection_rule_v2.slot_3[*].id),
    one(dynatrace_application_detection_rule_v2.slot_4[*].id),
    one(dynatrace_application_detection_rule_v2.slot_5[*].id),
  ])
}
