output "bundle_dir" {
  description = "Directory the bundle was written to. Point ../04-import at it."
  value       = var.output_dir
}

output "exported_schemas" {
  description = "Schemas that had non-default settings and were written to the bundle."
  value       = sort(keys(local.by_schema))
}

output "detection_rule_count" {
  description = "Number of detection rules written."
  value       = length(local.rules)
}
