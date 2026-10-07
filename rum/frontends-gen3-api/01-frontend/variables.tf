variable "dt_env_url" {
  description = "Dynatrace platform environment URL, e.g. https://<env-id>.apps.dynatrace.com. Set with TF_VAR_dt_env_url — this stack calls the platform REST API directly, so the DYNATRACE_ENV_URL fallback used by the other examples does not apply."
  type        = string
}

variable "dt_platform_token" {
  description = "Platform token with rum:frontends:write, rum:frontends:delete, settings:objects:read, and settings:objects:write. Set with TF_VAR_dt_platform_token."
  type        = string
  sensitive   = true
}

variable "display_name" {
  description = "Display name of the frontend, shown in the UI. Applied at creation; later changes are ignored by Terraform (rename in the UI, or through the builtin:rum.web.name / builtin:rum.mobile.name settings)."
  type        = string

  validation {
    condition     = length(var.display_name) >= 1 && length(var.display_name) <= 255
    error_message = "display_name must be 1-255 characters."
  }
}

variable "frontend_name" {
  description = "The frontend.name value stamped on every user.events and user.sessions record and used in DQL filters. Must be unique across web and mobile and cannot be changed in place — changing it replaces the frontend."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._~-]{1,255}$", var.frontend_name))
    error_message = "frontend_name must be 1-255 characters from A-Z, a-z, 0-9, '-', '_', '.', '~'. Spaces and other special characters are rejected."
  }
}

variable "application_type" {
  description = "How the frontend is instrumented: auto_injected (OneAgent injects the RUM JavaScript), agentless (you add the JavaScript snippet yourself), or mobile (Android/iOS SDK). Changing it replaces the frontend."
  type        = string

  validation {
    condition     = contains(["auto_injected", "agentless", "mobile"], var.application_type)
    error_message = "application_type must be one of: auto_injected, agentless, mobile."
  }
}

variable "detection_rules" {
  description = <<-E
    Detection rules that map incoming page loads to this frontend. Only valid for application_type = "auto_injected".
    matcher is one of DOMAIN_CONTAINS, DOMAIN_ENDS_WITH, DOMAIN_EQUALS, DOMAIN_MATCHES, DOMAIN_STARTS_WITH,
    URL_CONTAINS, URL_ENDS_WITH, URL_EQUALS, URL_STARTS_WITH.
    Rules are NOT guaranteed to be created in list order. If two rules can match the same URL, use
    ../../frontends-classic/02-detection-rules instead.
  E
  type = list(object({
    matcher     = string
    pattern     = string
    description = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for r in var.detection_rules : contains([
        "DOMAIN_CONTAINS", "DOMAIN_ENDS_WITH", "DOMAIN_EQUALS", "DOMAIN_MATCHES", "DOMAIN_STARTS_WITH",
        "URL_CONTAINS", "URL_ENDS_WITH", "URL_EQUALS", "URL_STARTS_WITH",
      ], r.matcher)
    ])
    error_message = "Each detection rule matcher must be one of the nine values listed in the variable description."
  }

  validation {
    condition     = length(var.detection_rules) == 0 || var.application_type == "auto_injected"
    error_message = "detection_rules only apply to auto_injected frontends. Agentless and mobile frontends are identified by the application ID in the snippet or SDK configuration, not by URL."
  }
}

variable "settle_duration" {
  description = "How long to wait after creating the frontend before reading or writing its settings. The frontend's entity takes up to ~40 seconds to appear, and settings calls fail with 404 until it does."
  type        = string
  default     = "60s"
}
