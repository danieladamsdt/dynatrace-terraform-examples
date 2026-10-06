locals {
  env_url  = trimsuffix(var.dt_env_url, "/")
  manifest = jsondecode(file("${var.bundle_dir}/frontend.json"))

  frontend_name = coalesce(var.frontend_name, local.manifest.frontend_name)
  display_name  = coalesce(var.display_name, local.manifest.display_name)

  frontend_type = {
    auto_injected = "WEB_AUTO_INJECTED"
    agentless     = "WEB_AGENTLESS"
    mobile        = "MOBILE"
  }[local.manifest.application_type]

  # The create call sets frontend.name and the display name, so those two
  # schemas are not replayed from the bundle.
  skipped_schemas = ["builtin:rum.frontend.name", "builtin:rum.web.name", "builtin:rum.mobile.name"]

  bundle_files = fileset(var.bundle_dir, "settings/*.json")
  bundle_settings = flatten([
    for f in local.bundle_files : [
      for i, v in jsondecode(file("${var.bundle_dir}/${f}")).values : {
        key       = "${jsondecode(file("${var.bundle_dir}/${f}")).schema_id}#${i}"
        schema_id = jsondecode(file("${var.bundle_dir}/${f}")).schema_id
        value     = v
      }
    ] if !contains(local.skipped_schemas, jsondecode(file("${var.bundle_dir}/${f}")).schema_id)
  ])

  # Only auto-injected frontends use detection rules.
  rules = local.manifest.application_type == "auto_injected" ? jsondecode(file("${var.bundle_dir}/detection-rules.json")) : []
}

# --- 1. The frontend (same mechanism as ../01-frontend) ----------------------

resource "terraform_data" "identity" {
  input = {
    frontend_name = local.frontend_name
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
    displayName  = local.display_name
    frontendName = local.frontend_name
    type         = local.frontend_type
  })

  lifecycle {
    ignore_changes       = [data]
    replace_triggered_by = [terraform_data.identity]
  }
}

resource "time_sleep" "settle" {
  create_duration = var.settle_duration

  triggers = {
    frontend_id = restapi_object.frontend.id
  }
}

# The request header — and therefore the token — is recorded in state by this
# data source. State is gitignored; do not share it.
data "http" "entity" {
  url             = "${local.env_url}/platform/classic/environment-api/v2/settings/objects?schemaIds=builtin:rum.frontend.name&fields=scope,value&filter=${urlencode("value.frontendName = '${local.frontend_name}'")}"
  request_headers = { Authorization = "Bearer ${var.dt_platform_token}" }

  depends_on = [time_sleep.settle]

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && length(jsondecode(self.response_body).items) == 1
      error_message = "Could not resolve the entity ID for frontend '${local.frontend_name}'. If it was just created, increase settle_duration."
    }
  }
}

locals {
  entity_id = jsondecode(data.http.entity.response_body).items[0].scope
}

# --- 2. Settings ---------------------------------------------------------------
#
# Most of these objects already exist with default values the moment the
# frontend is created, so applying one updates it in place rather than creating
# it. That also means they cannot be deleted: see "Tearing down" in the README.

resource "dynatrace_generic_setting" "bundle" {
  for_each = { for s in local.bundle_settings : s.key => s }

  schema = each.value.schema_id
  scope  = local.entity_id
  value  = jsonencode(each.value.value)
}
