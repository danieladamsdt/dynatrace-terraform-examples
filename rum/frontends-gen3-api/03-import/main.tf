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

  # Each file is { schema_id, values = [...] }; decode every file once.
  bundle_files = {
    for f in fileset(var.bundle_dir, "settings/*.json") :
    f => jsondecode(file("${var.bundle_dir}/${f}"))
  }

  bundle_settings = flatten([
    for f, b in local.bundle_files : [
      for i, v in b.values : {
        key       = "${b.schema_id}#${i}"
        schema_id = b.schema_id
        value     = v
      }
    ] if !contains(local.skipped_schemas, b.schema_id)
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

# Reads every builtin:rum.frontend.name object and matches on the name; each
# object's scope is the entity ID. depends_on defers the read until after the
# wait.
data "dynatrace_generic_settings" "frontends" {
  schema = "builtin:rum.frontend.name"

  depends_on = [time_sleep.settle]
}

locals {
  matches   = [for s in data.dynatrace_generic_settings.frontends.values : s.scope if jsondecode(s.value).frontendName == local.frontend_name]
  entity_id = try(local.matches[0], "")
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
