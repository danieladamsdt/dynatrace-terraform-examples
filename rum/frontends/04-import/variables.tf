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
  description = "Directory written by ../03-export, containing frontend.json, settings/*.json, and detection-rules.json."
  type        = string
  default     = "../03-export/bundle"
}

variable "frontend_name" {
  description = "frontend.name for the imported frontend. Null keeps the name from the bundle. frontend.name is unique per environment, so importing into the environment you exported from requires a different name."
  type        = string
  default     = null
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
