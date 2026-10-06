# Detection rules take the entity ID (APPLICATION-…). Every frontend has a
# builtin:rum.frontend.name object whose scope is that ID, so reading them all
# and matching on the name resolves it without DQL or a second provider.
data "dynatrace_generic_settings" "frontends" {
  schema = "builtin:rum.frontend.name"
}

locals {
  matches        = [for s in data.dynatrace_generic_settings.frontends.values : s.scope if jsondecode(s.value).frontendName == var.frontend_name]
  application_id = try(local.matches[0], "")
}
