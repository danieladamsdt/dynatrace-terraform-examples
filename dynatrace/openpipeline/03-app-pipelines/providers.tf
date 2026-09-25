# Credentials are read from the environment when the variables are left null:
#   export DYNATRACE_ENV_URL="https://<env-id>.apps.dynatrace.com"
#   export DYNATRACE_PLATFORM_TOKEN="dt0s16.********"
#
# Platform tokens (or an OAuth client) are strongly preferred over classic API
# tokens here. A settings object created with a classic API token has an empty
# owner, which makes it world-readable/writable and means dynatrace_settings_permissions
# cannot restrict it afterwards.
provider "dynatrace" {
  dt_env_url     = var.dt_env_url
  platform_token = var.dt_platform_token
}
