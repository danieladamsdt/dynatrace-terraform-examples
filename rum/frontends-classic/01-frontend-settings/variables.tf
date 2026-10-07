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
  description = "frontend.name of an existing frontend — the value you filter on in DQL. The stack looks up its entity ID (APPLICATION-… or MOBILE_APPLICATION-…) from this."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._~-]{1,255}$", var.frontend_name))
    error_message = "frontend_name must be 1-255 characters from A-Z, a-z, 0-9, '-', '_', '.', '~'."
  }
}

variable "rum_enabled" {
  description = "Whether RUM is enabled for the frontend."
  type        = bool
  default     = true
}

variable "enabled_on_grail" {
  description = "Whether the frontend's RUM data is stored in Grail, where DQL (user.events, user.sessions) reads it. Leave true for the latest Dynatrace."
  type        = bool
  default     = true
}

variable "cost_and_traffic_control" {
  description = "Percentage of user sessions captured, 0-100."
  type        = number
  default     = 100

  validation {
    condition     = var.cost_and_traffic_control >= 0 && var.cost_and_traffic_control <= 100
    error_message = "cost_and_traffic_control must be between 0 and 100."
  }
}

variable "session_replay_enabled" {
  description = "Web frontends only. Whether session replay is enabled."
  type        = bool
  default     = false
}

variable "extra_settings" {
  description = <<-E
    Any other per-frontend settings object, written with dynatrace_generic_setting against this frontend.
    Each entry is { schema = "builtin:…", value = { … } }. List a schema's fields with
    `dtctl get settings-schema <schema>`. Several entries may share a schema if the schema allows
    multiple objects (for example builtin:rum.web.xhr-exclusion).
    Do not use this for builtin:rum.frontend.name, builtin:rum.web.name or builtin:rum.mobile.name:
    those objects are created with the frontend and the API refuses to delete them, so a destroy fails.
  E
  type = list(object({
    schema = string
    value  = any
  }))
  default = []

  validation {
    condition = !anytrue([
      for s in var.extra_settings : contains([
        "builtin:rum.frontend.name", "builtin:rum.web.name", "builtin:rum.mobile.name",
      ], s.schema)
    ])
    error_message = "The name schemas cannot be managed here; see the variable description."
  }
}
