variable "dt_env_url" {
  description = "Dynatrace platform environment URL, e.g. https://<env-id>.apps.dynatrace.com. Falls back to $DYNATRACE_ENV_URL."
  type        = string
  default     = null
}

variable "dt_platform_token" {
  description = "Dynatrace platform token with settings:objects:read and settings:objects:write. Falls back to $DYNATRACE_PLATFORM_TOKEN."
  type        = string
  default     = null
  sensitive   = true
}

variable "frontend_name" {
  description = "frontend.name of an existing auto-injected frontend. The stack looks up its entity ID (APPLICATION-…) from this."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._~-]{1,255}$", var.frontend_name))
    error_message = "frontend_name must be 1-255 characters from A-Z, a-z, 0-9, '-', '_', '.', '~'."
  }
}

variable "insert_after" {
  description = "Settings object ID of an existing detection rule to place this block after. Null appends the block to the end of the environment-wide rule list."
  type        = string
  default     = null
}

variable "detection_rules" {
  description = <<-E
    Ordered detection rules for this frontend, highest precedence first. Between 1 and 5 entries;
    see rules.tf to add slots. matcher is one of DOMAIN_CONTAINS, DOMAIN_ENDS_WITH, DOMAIN_EQUALS,
    DOMAIN_MATCHES, DOMAIN_STARTS_WITH, URL_CONTAINS, URL_ENDS_WITH, URL_EQUALS, URL_STARTS_WITH.
  E
  type = list(object({
    matcher     = string
    pattern     = string
    description = optional(string)
  }))

  validation {
    condition     = length(var.detection_rules) >= 1 && length(var.detection_rules) <= 5
    error_message = "Provide between 1 and 5 detection rules, or add slots in rules.tf."
  }

  validation {
    condition = alltrue([
      for r in var.detection_rules : contains([
        "DOMAIN_CONTAINS", "DOMAIN_ENDS_WITH", "DOMAIN_EQUALS", "DOMAIN_MATCHES", "DOMAIN_STARTS_WITH",
        "URL_CONTAINS", "URL_ENDS_WITH", "URL_EQUALS", "URL_STARTS_WITH",
      ], r.matcher)
    ])
    error_message = "Each detection rule matcher must be one of the nine values listed in the variable description."
  }
}
