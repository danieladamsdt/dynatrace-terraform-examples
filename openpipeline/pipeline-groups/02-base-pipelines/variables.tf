variable "dt_env_url" {
  description = "Dynatrace platform environment URL. Falls back to $DYNATRACE_ENV_URL."
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
  description = "Prefix for display names and custom_ids. Keep identical across environments so base pipelines stay comparable."
  type        = string
  default     = "platform"
}

variable "security_context_field" {
  description = "Record field whose value becomes dt.security_context. Drives who can read the data in Grail."
  type        = string
  default     = "k8s.namespace.name"
}

variable "cost_center_field" {
  description = "Record field whose value becomes dt.cost.costcenter."
  type        = string
  default     = "k8s.cluster.name"
}
