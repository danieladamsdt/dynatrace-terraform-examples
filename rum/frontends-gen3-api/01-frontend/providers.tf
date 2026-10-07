# Unlike the other examples, credentials are plain variables rather than
# DYNATRACE_* environment fallbacks: the restapi provider has no such fallback,
# and both providers must use the same tenant and token. Export them as
# TF_VAR_dt_env_url and TF_VAR_dt_platform_token (see the README).
provider "dynatrace" {
  dt_env_url     = var.dt_env_url
  platform_token = var.dt_platform_token
}

# Calls the Gen3 RUM API (POST/DELETE /platform/rum/v1/frontends), which the
# dynatrace provider has no resource for.
provider "restapi" {
  uri                  = trimsuffix(var.dt_env_url, "/")
  write_returns_object = true
  id_attribute         = "id"

  headers = {
    Authorization = "Bearer ${var.dt_platform_token}"
    Content-Type  = "application/json"
  }
}
