# Credentials are read from the environment when the variables are left null:
#   export DYNATRACE_ENV_URL="https://<env-id>.apps.dynatrace.com"
#   export DYNATRACE_PLATFORM_TOKEN="dt0s16.********"
#
# Bucket management is a platform API, so a platform token (or OAuth client) is
# required. A classic API token cannot manage Grail buckets.
provider "dynatrace" {
  dt_env_url     = var.dt_env_url
  platform_token = var.dt_platform_token
}
