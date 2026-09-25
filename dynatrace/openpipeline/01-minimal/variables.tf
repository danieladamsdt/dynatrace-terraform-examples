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

variable "name_prefix" {
  description = "Prefix applied to every display name and custom_id so this example can be deployed repeatedly without collisions."
  type        = string
  default     = "example"
}

variable "target_bucket" {
  description = "Grail bucket the member pipeline writes into. Must already exist."
  type        = string
  default     = "default_logs"
}
