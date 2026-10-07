locals {
  env_url = trimsuffix(var.dt_env_url, "/")

  # Gen3 RUM API enum for each application_type.
  frontend_type = {
    auto_injected = "WEB_AUTO_INJECTED"
    agentless     = "WEB_AGENTLESS"
    mobile        = "MOBILE"
  }[var.application_type]
}

# --- 1. The frontend ---------------------------------------------------------
#
# POST /platform/rum/v1/frontends creates the frontend, its frontend.name, and
# its display name in one call. The API has no GET, so refresh reads the
# frontend's builtin:rum.frontend.name settings object instead, and ignores
# what comes back.

# frontend_name and type cannot be updated in place. Tracking them here makes a
# change replace the frontend; display_name changes are deliberately ignored.
resource "terraform_data" "identity" {
  input = {
    frontend_name = var.frontend_name
    type          = local.frontend_type
  }
}

resource "restapi_object" "frontend" {
  path         = "/platform/rum/v1/frontends"
  read_path    = "/platform/settings/v1/objects"
  query_string = "schema-id=builtin:rum.frontend.name&scope={id}"
  destroy_path = "/platform/rum/v1/frontends/{id}"

  ignore_all_server_changes = true

  data = jsonencode({
    displayName  = var.display_name
    frontendName = var.frontend_name
    type         = local.frontend_type
  })

  lifecycle {
    ignore_changes       = [data]
    replace_triggered_by = [terraform_data.identity]
  }
}

# --- 2. Wait for the entity, then resolve its entity ID ----------------------
#
# The create call returns a Smartscape ID (FRONTEND-…). Detection rules and the
# dynatrace provider's settings resources need the entity ID (APPLICATION-… or
# MOBILE_APPLICATION-…), which is not derivable from it. frontend.name is
# unique, so it identifies the entity.

resource "time_sleep" "settle" {
  create_duration = var.settle_duration

  triggers = {
    frontend_id = restapi_object.frontend.id
  }
}

# Reads every builtin:rum.frontend.name object and matches on the name; each
# object's scope is the entity ID. depends_on defers the read until after the
# wait.
data "dynatrace_generic_settings" "frontends" {
  schema = "builtin:rum.frontend.name"

  depends_on = [time_sleep.settle]
}

locals {
  matches   = [for s in data.dynatrace_generic_settings.frontends.values : s.scope if jsondecode(s.value).frontendName == var.frontend_name]
  entity_id = try(local.matches[0], "")
}

# --- 3. Detection rules (auto-injected only) ---------------------------------
#
# New rules are appended to the end of the environment-wide rule list, so they
# rank below every existing rule. Creation order within one apply is not
# guaranteed — see ../../frontends-classic/02-detection-rules when order matters.

resource "dynatrace_application_detection_rule_v2" "this" {
  for_each = { for i, r in var.detection_rules : format("%03d", i) => r }

  application_id = local.entity_id
  matcher        = each.value.matcher
  pattern        = each.value.pattern
  description    = each.value.description
}
