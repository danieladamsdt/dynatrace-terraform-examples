# ---------------------------------------------------------------------------
# !! SINGLETON RESOURCE — READ BEFORE APPLYING !!
#
# dynatrace_openpipeline_v2_logs_routing represents the ENTIRE logs routing
# table for the tenant, not one rule. Applying it overwrites every logs routing
# rule in the environment, including rules created in the UI and rules managed
# by another Terraform workspace or by Monaco.
#
# Consequences:
#   * All logs routing for one Dynatrace environment must be owned by exactly
#     one state file. Splitting it across stacks means whichever applies last
#     silently deletes the others' rules.
#   * Before the first apply, export the existing table so nothing is lost:
#       terraform-provider-dynatrace -export dynatrace_openpipeline_v2_logs_routing
#
# The same applies to the *_routing resource of every other record type
# (events, bizevents, spans, metrics, ...).
# ---------------------------------------------------------------------------

resource "dynatrace_openpipeline_v2_logs_routing" "this" {
  routing_entries {
    # Application rules, most specific first (see var.applications.route_priority).
    dynamic "routing_entry" {
      for_each = local.app_keys_by_route_priority

      content {
        enabled       = true
        description   = "${var.applications[routing_entry.value].display_name} (${var.environment_name})"
        pipeline_type = "custom"
        pipeline_id   = dynatrace_openpipeline_v2_logs_pipelines.member[routing_entry.value].id
        matcher       = var.applications[routing_entry.value].route_matcher
      }
    }

    # Catch-all, always last. Without it, unmatched records are dropped.
    routing_entry {
      enabled             = true
      description         = "Catch-all: unmatched records use the built-in pipeline"
      pipeline_type       = "builtin"
      builtin_pipeline_id = var.default_route_builtin_pipeline_id
      matcher             = var.default_route_matcher
    }
  }
}
