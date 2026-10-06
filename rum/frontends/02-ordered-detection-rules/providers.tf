# Credentials are plain variables here so the entity lookup (hashicorp/http)
# and the dynatrace provider use the same tenant and token. Export them as
# TF_VAR_dt_env_url and TF_VAR_dt_platform_token (see the README).
provider "dynatrace" {
  dt_env_url     = var.dt_env_url
  platform_token = var.dt_platform_token
}
