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

variable "environment_name" {
  description = "Short name of the Dynatrace environment this stack targets (dev, staging, prod). Used in display names so objects are identifiable in the UI."
  type        = string
}

variable "pipeline_group_name" {
  description = "Display name of the pipeline group created by this stack."
  type        = string
  default     = "Application logs"
}

# --- Base pipelines -------------------------------------------------------
# Produced by the 02-base-pipelines stack. Passed in as plain strings rather
# than read through a data source, because the provider exposes no data source
# for OpenPipeline settings objects (verified against provider v1.105).

variable "pre_member_base_pipeline_ids" {
  description = "Base pipeline IDs to run, in order, BEFORE the routed member pipeline."
  type        = list(string)
  default     = []
}

variable "post_member_base_pipeline_ids" {
  description = "Base pipeline IDs to run, in order, AFTER the routed member pipeline."
  type        = list(string)
  default     = []
}

variable "base_pipeline_stages" {
  description = "Stages the base pipelines are permitted to contribute to the composition."
  type        = list(string)
  default     = ["processing", "securityContext", "costAllocation"]
}

# --- Member pipeline boundaries -------------------------------------------

variable "member_stages" {
  description = <<-EOT
    Stages member pipelines may define. Stages outside this set are ignored even
    if a member pipeline configures them — this is the guardrail that stops teams
    from, say, reassigning their own security context.

    type must be one of: include, exclude, includeAll.
    Valid stage names: costAllocation, dataExtraction, davis, metricExtraction,
    processing, productAllocation, securityContext, smartscapeEdgeExtraction,
    smartscapeNodeExtraction, storage.
  EOT
  type = object({
    type    = string
    include = optional(list(string))
    exclude = optional(list(string))
  })
  default = {
    type    = "include"
    include = ["processing", "metricExtraction", "storage"]
  }

  validation {
    condition     = contains(["include", "exclude", "includeAll"], var.member_stages.type)
    error_message = "member_stages.type must be one of: include, exclude, includeAll."
  }
}

# --- Applications ---------------------------------------------------------

variable "applications" {
  description = <<-EOT
    One entry per onboarded application. Each entry produces a member pipeline,
    a membership in the pipeline group, and a routing rule — the three objects
    that previously had to be created by hand and kept in sync.

    Map keys become the pipeline custom_id, so they must be stable: changing a
    key destroys and recreates the pipeline.

      route_priority  Lower numbers are evaluated first. Must be unique.
      route_matcher   DQL matcher deciding which records enter this pipeline.
      bucket_name     Grail bucket to store into. Must already exist. Omit to
                      leave storage at the group/default behaviour.
      added_fields    Static fields added to every matching record.
      drop_matcher    Records matching this are dropped before anything else.
      dql_script      Free-form DQL processor, applied last.
  EOT
  type = map(object({
    display_name   = string
    route_priority = number
    route_matcher  = string
    bucket_name    = optional(string)
    added_fields   = optional(map(string), {})
    drop_matcher   = optional(string)
    dql_script     = optional(string)
  }))
  default = {}

  validation {
    condition     = length(distinct([for app in var.applications : app.route_priority])) == length(var.applications)
    error_message = "route_priority must be unique across applications, otherwise routing evaluation order is not deterministic."
  }

  validation {
    condition     = alltrue([for key in keys(var.applications) : can(regex("^[a-z0-9][a-z0-9-]{0,48}[a-z0-9]$", key))])
    error_message = "Application keys must be lowercase alphanumeric with dashes (they become the pipeline custom_id)."
  }
}

# --- Catch-all route ------------------------------------------------------

variable "default_route_builtin_pipeline_id" {
  description = "Built-in pipeline that receives everything no application matcher claimed."
  type        = string
  default     = "default"
}

variable "default_route_matcher" {
  description = "Matcher for the catch-all routing entry. Leave as true so nothing is silently dropped."
  type        = string
  default     = "true"
}
