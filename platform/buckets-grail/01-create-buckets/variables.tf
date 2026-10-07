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

variable "buckets" {
  description = <<-EOT
    Custom Grail buckets to manage, keyed by bucket name.

      table           Which table the bucket stores: logs, spans, events, or
                      bizevents. IMMUTABLE: changing it on an existing bucket
                      would delete and re-create the bucket, so prevent_destroy
                      makes the plan fail instead.
      retention_days  How long records are kept. Raising it is safe. LOWERING IT
                      DELETES the records older than the new value.
      display_name    Label shown in the UI. Safe to change at any time.

    The map key is the bucket name: 3-100 characters, starts with a letter,
    lowercase letters, digits, underscores, and hyphens only. It is IMMUTABLE,
    for the same reason as table.
  EOT
  type = map(object({
    table          = string
    retention_days = number
    display_name   = optional(string)
  }))

  validation {
    condition = alltrue([
      for name in keys(var.buckets) : can(regex("^[a-z][a-z0-9_-]{2,99}$", name))
    ])
    error_message = "Bucket names must be 3-100 characters, start with a lowercase letter, and contain only lowercase letters, digits, underscores, and hyphens."
  }

  validation {
    condition = alltrue([
      for b in values(var.buckets) : contains(["logs", "spans", "events", "bizevents"], b.table)
    ])
    error_message = "table must be one of: logs, spans, events, bizevents."
  }

  validation {
    condition = alltrue([
      for b in values(var.buckets) : b.retention_days == floor(b.retention_days) && b.retention_days >= 1 && b.retention_days <= 3657
    ])
    error_message = "retention_days must be a whole number of days from 1 to 3657."
  }
}
