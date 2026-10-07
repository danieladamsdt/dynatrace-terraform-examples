locals {
  env_url = trimsuffix(var.dt_env_url, "/")
  api     = "${local.env_url}/platform/classic/environment-api/v2/settings/objects"
  auth    = { Authorization = "Bearer ${var.dt_platform_token}" }

  # Every schema that can hold a per-frontend settings object, verified against
  # the schema list of a current tenant. Missing or default-valued schemas
  # simply return no objects and are skipped.
  frontend_schemas = [
    "builtin:rum.frontend.name",
    "builtin:rum.web.name",
    "builtin:rum.web.enablement",
    "builtin:rum.web.automatic-injection",
    "builtin:rum.web.beacon-endpoint",
    "builtin:rum.web.browser-exclusion",
    "builtin:rum.web.capture-custom-properties",
    "builtin:rum.web.capture-properties",
    "builtin:rum.web.custom-injection-rules",
    "builtin:rum.web.frontend-backend-linking",
    "builtin:rum.web.injection.cookie",
    "builtin:rum.web.ipaddress-exclusion",
    "builtin:rum.web.manual-insertion",
    "builtin:rum.web.rum-cookies-upgrade",
    "builtin:rum.web.rum-javascript-updates",
    "builtin:rum.web.xhr-exclusion",
    "builtin:rum.mobile.name",
    "builtin:rum.mobile.enablement",
    "builtin:rum.mobile.beacon-endpoint",
    "builtin:rum.mobile.capture-properties",
    "builtin:rum.mobile.frontend-backend-linking",
    "builtin:rum.mobile.privacy",
    "builtin:sessionreplay.web.privacy-preferences",
    "builtin:sessionreplay.web.resource-capturing",
  ]
}

# The request headers — and therefore the token — are recorded in state by
# these data sources. Delete terraform.tfstate* after exporting.

data "http" "entity" {
  url             = "${local.api}?schemaIds=builtin:rum.frontend.name&fields=scope,value&filter=${urlencode("value.frontendName = '${var.frontend_name}'")}"
  request_headers = local.auth

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && length(jsondecode(self.response_body).items) == 1
      error_message = "No frontend named '${var.frontend_name}' found."
    }
  }
}

locals {
  entity_id = jsondecode(data.http.entity.response_body).items[0].scope
}

data "http" "settings" {
  url             = "${local.api}?schemaIds=${join(",", local.frontend_schemas)}&scopes=${local.entity_id}&fields=schemaId,value&pageSize=500"
  request_headers = local.auth

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Reading settings failed with HTTP ${self.status_code}: ${self.response_body}"
    }
  }
}

# Detection rules are a single ordered list for the whole environment. The API
# returns them in precedence order; keep that order and filter to this frontend.
data "http" "rules" {
  url             = "${local.api}?schemaIds=builtin:rum.web.app-detection&fields=value&pageSize=500"
  request_headers = local.auth

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Reading detection rules failed with HTTP ${self.status_code}: ${self.response_body}"
    }
  }
}

locals {
  settings = jsondecode(data.http.settings.response_body).items

  # Name settings carry the display name; the schema differs for web and mobile.
  is_mobile    = startswith(local.entity_id, "MOBILE_APPLICATION-")
  display_name = one([for s in local.settings : s.value.applicationName if s.schemaId == (local.is_mobile ? "builtin:rum.mobile.name" : "builtin:rum.web.name")])

  # Singleton schemas have one object each; multi-object schemas (custom
  # injection rules, XHR exclusions) have several, so each schema is written as
  # one file holding a list of values.
  by_schema = {
    for schema in distinct([for s in local.settings : s.schemaId]) :
    schema => [for s in local.settings : s.value if s.schemaId == schema]
  }

  rules = [
    for r in jsondecode(data.http.rules.response_body).items : {
      matcher     = r.value.matcher
      pattern     = r.value.pattern
      description = try(r.value.description, null)
    } if var.include_all_detection_rules || r.value.applicationId == local.entity_id
  ]

  manifest = {
    format_version   = 1
    frontend_name    = var.frontend_name
    display_name     = local.display_name
    application_type = local.is_mobile ? "mobile" : var.application_type
    exported_from    = local.env_url
  }
}

# --- The bundle ---------------------------------------------------------------

resource "local_file" "manifest" {
  filename = "${var.output_dir}/frontend.json"
  content  = "${jsonencode(local.manifest)}\n"
}

resource "local_file" "settings" {
  for_each = local.by_schema

  # Schema IDs contain ':', which is not a legal filename character on Windows.
  filename = "${var.output_dir}/settings/${replace(each.key, ":", "_")}.json"
  content  = "${jsonencode({ schema_id = each.key, values = each.value })}\n"
}

resource "local_file" "rules" {
  count = local.is_mobile ? 0 : 1

  filename = "${var.output_dir}/detection-rules.json"
  content  = "${jsonencode(local.rules)}\n"
}
