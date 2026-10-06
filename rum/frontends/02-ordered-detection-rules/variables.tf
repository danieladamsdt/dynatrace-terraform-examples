variable "dt_env_url" {
  description = "Dynatrace platform environment URL, e.g. https://<env-id>.apps.dynatrace.com. Set with TF_VAR_dt_env_url — this stack calls the platform REST API directly, so the DYNATRACE_ENV_URL fallback used by the other examples does not apply."
  type        = string
}

variable "dt_platform_token" {
  description = "Platform token with settings:objects:read, and settings:objects:write. Set with TF_VAR_dt_platform_token."
  type        = string
  sensitive   = true
}

variable "frontend_name" {
  description = "frontend.name of an existing auto-injected frontend (created by ../01-frontend or in the UI). Used to look up its entity ID."
  type        = string
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
