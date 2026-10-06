variable "dt_env_url" {
  description = "Dynatrace platform environment URL, e.g. https://<env-id>.apps.dynatrace.com. Set with TF_VAR_dt_env_url — this stack calls the platform REST API directly, so the DYNATRACE_ENV_URL fallback used by the other examples does not apply."
  type        = string
}

variable "dt_platform_token" {
  description = "Platform token with rum:frontends:write, rum:frontends:delete, settings:objects:read, and settings:objects:write. Set with TF_VAR_dt_platform_token."
  type        = string
  sensitive   = true
}

variable "bundle_dir" {
  description = "Directory written by ../02-export, containing frontend.json, settings/*.json, and detection-rules.json."
  type        = string
  default     = "../02-export/bundle"
}

variable "frontend_name" {
  description = "frontend.name for the imported frontend. Null keeps the name from the bundle. frontend.name is unique per environment, so importing into the environment you exported from requires a different name."
  type        = string
  default     = null

  validation {
    condition     = var.frontend_name == null || can(regex("^[A-Za-z0-9._~-]{1,255}$", coalesce(var.frontend_name, "x")))
    error_message = "frontend_name must be 1-255 characters from A-Z, a-z, 0-9, '-', '_', '.', '~'."
  }
}

variable "display_name" {
  description = "Display name for the imported frontend. Null keeps the name from the bundle."
  type        = string
  default     = null
}

variable "settle_duration" {
  description = "How long to wait after creating the frontend before writing its settings. The entity takes up to ~40 seconds to appear, and settings calls fail with 404 until it does."
  type        = string
  default     = "60s"
}

variable "insert_rules_after" {
  description = "Settings object ID of an existing detection rule to place the imported rules after. Null appends them to the end of the environment-wide list."
  type        = string
  default     = null
}
