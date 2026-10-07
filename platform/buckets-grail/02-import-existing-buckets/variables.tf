variable "dt_env_url" {
  description = "Dynatrace platform environment URL, e.g. https://<env-id>.apps.dynatrace.com. Falls back to $DYNATRACE_ENV_URL."
  type        = string
  default     = null
}

variable "dt_platform_token" {
  description = "Dynatrace platform token with the bucket-definitions scopes (storage:bucket-definitions:read and :write). Falls back to $DYNATRACE_PLATFORM_TOKEN."
  type        = string
  default     = null
  sensitive   = true
}

variable "existing_buckets" {
  description = <<-EOT
    Buckets that already exist in the tenant and should be brought under
    Terraform, keyed by bucket name. Each value must match the bucket's CURRENT
    settings (see the README for how to read them); Terraform then manages it
    from there.

      table           Must equal the bucket's current table. IMMUTABLE.
      retention_days  Must equal the bucket's current retention on the first
                      apply. After that, raising it is safe; LOWERING IT
                      DELETES the records older than the new value.
      display_name    Must equal the current display name on the first apply.
                      Safe to change afterward.
  EOT
  type = map(object({
    table          = string
    retention_days = number
    display_name   = optional(string)
  }))

  validation {
    condition = alltrue([
      for name in keys(var.existing_buckets) : can(regex("^[a-z][a-z0-9_-]{2,99}$", name))
    ])
    error_message = "Bucket names must be 3-100 characters, start with a lowercase letter, and contain only lowercase letters, digits, underscores, and hyphens."
  }

  validation {
    condition = alltrue([
      for b in values(var.existing_buckets) : contains(["logs", "spans", "events", "bizevents"], b.table)
    ])
    error_message = "table must be one of: logs, spans, events, bizevents."
  }

  validation {
    condition = alltrue([
      for b in values(var.existing_buckets) : b.retention_days == floor(b.retention_days) && b.retention_days >= 1 && b.retention_days <= 3657
    ])
    error_message = "retention_days must be a whole number of days from 1 to 3657."
  }
}
