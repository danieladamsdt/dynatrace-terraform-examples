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

# The request header — and therefore the token — is recorded in state by this
# data source. State is gitignored; do not share it.
data "http" "entity" {
  url             = "${local.env_url}/platform/classic/environment-api/v2/settings/objects?schemaIds=builtin:rum.frontend.name&fields=scope,value&filter=${urlencode("value.frontendName = '${var.frontend_name}'")}"
  request_headers = { Authorization = "Bearer ${var.dt_platform_token}" }

  depends_on = [time_sleep.settle]

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && length(jsondecode(self.response_body).items) == 1
      error_message = "Could not resolve the entity ID for frontend '${var.frontend_name}'. If the frontend was just created, increase settle_duration."
    }
  }
}

locals {
  entity_id = jsondecode(data.http.entity.response_body).items[0].scope
}

# --- 3. Detection rules (auto-injected only) ---------------------------------
#
# New rules are appended to the end of the environment-wide rule list, so they
# rank below every existing rule. Creation order within one apply is not
# guaranteed — see ../02-ordered-detection-rules when order matters.

resource "dynatrace_application_detection_rule_v2" "this" {
  for_each = { for i, r in var.detection_rules : format("%03d", i) => r }

  application_id = local.entity_id
  matcher        = each.value.matcher
  pattern        = each.value.pattern
  description    = each.value.description
}
