variable "dt_env_url" {
  description = "Dynatrace platform environment URL, e.g. https://<env-id>.apps.dynatrace.com. Set with TF_VAR_dt_env_url — this stack calls the platform REST API directly, so the DYNATRACE_ENV_URL fallback used by the other examples does not apply."
  type        = string
}

variable "dt_platform_token" {
  description = "Platform token with settings:objects:read. Set with TF_VAR_dt_platform_token."
  type        = string
  sensitive   = true
}

variable "frontend_name" {
  description = "frontend.name of the frontend to export."
  type        = string
}

variable "application_type" {
  description = "auto_injected, agentless, or mobile. Recorded in the bundle so ../04-import recreates the same kind. Web vs. mobile is detected from the entity ID, but auto-injected vs. agentless is not exposed by any API, so state it here."
  type        = string
  default     = "auto_injected"

  validation {
    condition     = contains(["auto_injected", "agentless", "mobile"], var.application_type)
    error_message = "application_type must be one of: auto_injected, agentless, mobile."
  }
}

variable "output_dir" {
  description = "Directory the bundle is written to, relative to this stack. Created if missing."
  type        = string
  default     = "bundle"
}

variable "include_all_detection_rules" {
  description = "Detection rules are one environment-wide list. By default only rules that point at this frontend are exported; set true to keep nothing back (rarely useful)."
  type        = bool
  default     = false
}
