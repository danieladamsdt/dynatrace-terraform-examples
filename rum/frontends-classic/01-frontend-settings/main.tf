# Every frontend has a builtin:rum.frontend.name object whose scope is the
# frontend's entity ID. Reading them all and matching on the name resolves the
# ID without DQL or a second provider.
data "dynatrace_generic_settings" "frontends" {
  schema = "builtin:rum.frontend.name"
}

locals {
  matches = [
    for s in data.dynatrace_generic_settings.frontends.values : s.scope
    if jsondecode(s.value).frontendName == var.frontend_name
  ]
  application_id = try(local.matches[0], "")
  is_mobile      = startswith(local.application_id, "MOBILE_APPLICATION-")
}

# --- Enablement and Grail storage -----------------------------------------------
#
# Every frontend already has an enablement object holding defaults, so this
# updates it in place. Without enabled_on_grail the data is not queryable with
# DQL.

resource "dynatrace_web_app_enablement" "this" {
  count = local.is_mobile ? 0 : 1

  application_id = local.application_id

  rum {
    enabled                  = var.rum_enabled
    enabled_on_grail         = var.enabled_on_grail
    cost_and_traffic_control = var.cost_and_traffic_control
  }

  session_replay {
    enabled                  = var.session_replay_enabled
    cost_and_traffic_control = 100
  }

  lifecycle {
    precondition {
      condition     = length(local.matches) == 1
      error_message = "No frontend named '${var.frontend_name}' found. Create it first — see the guide."
    }
  }
}

resource "dynatrace_mobile_app_enablement" "this" {
  count = local.is_mobile ? 1 : 0

  application_id = local.application_id

  rum {
    enabled                  = var.rum_enabled
    enabled_on_grail         = var.enabled_on_grail
    cost_and_traffic_control = var.cost_and_traffic_control
  }

  session_replay {
    on_crash = false
  }

  lifecycle {
    precondition {
      condition     = length(local.matches) == 1
      error_message = "No frontend named '${var.frontend_name}' found. Create it first — see the guide."
    }
  }
}

# --- Everything else ------------------------------------------------------------

resource "dynatrace_generic_setting" "extra" {
  for_each = { for i, s in var.extra_settings : "${s.schema}#${i}" => s }

  schema = each.value.schema
  scope  = local.application_id
  value  = jsonencode(each.value.value)
}
