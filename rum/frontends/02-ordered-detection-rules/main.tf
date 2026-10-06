locals {
  env_url = trimsuffix(var.dt_env_url, "/")
}

# The rules need the entity ID (APPLICATION-…), not the Smartscape FRONTEND-… ID.
# frontend.name is unique, so it identifies the entity.
#
# The request header — and therefore the token — is recorded in state by this
# data source. State is gitignored; do not share it.
data "http" "entity" {
  url             = "${local.env_url}/platform/classic/environment-api/v2/settings/objects?schemaIds=builtin:rum.frontend.name&fields=scope,value&filter=${urlencode("value.frontendName = '${var.frontend_name}'")}"
  request_headers = { Authorization = "Bearer ${var.dt_platform_token}" }

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
