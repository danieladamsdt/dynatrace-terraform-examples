# ---------------------------------------------------------------------------
# The smallest complete OpenPipeline group: one base pipeline, one member
# pipeline, the group that composes them, and the routing rule that feeds it.
#
# Read this file top to bottom before looking at the multi-stack examples in
# ../02-base-pipelines and ../03-app-pipelines.
# ---------------------------------------------------------------------------

# 1. BASE PIPELINE ----------------------------------------------------------
# Shared logic every member of the group must run. Owned by the platform team.
# notRoutable: nothing routes here directly; it only runs as part of a group.
# group_role "compositionPipeline" is the deprecated former name of
# "basePipeline" -- same role, old spelling. Use basePipeline.
resource "dynatrace_openpipeline_v2_logs_pipelines" "base" {
  display_name = "${var.name_prefix} base"
  custom_id    = "${var.name_prefix}-base"
  group_role   = "basePipeline"
  routing      = "notRoutable"

  processing {
    processors {
      processor {
        type        = "fieldsAdd"
        id          = "add_managed_by"
        description = "Stamp records so it is obvious where the config came from"
        matcher     = "true"
        enabled     = true

        fields_add {
          fields {
            field {
              name  = "managed_by"
              value = "terraform"
            }
          }
        }
      }
    }
  }
}

# 2. MEMBER PIPELINE --------------------------------------------------------
# Team-specific logic. routable: routing rules may target it directly.
resource "dynatrace_openpipeline_v2_logs_pipelines" "member" {
  display_name = "${var.name_prefix} member"
  custom_id    = "${var.name_prefix}-member"
  group_role   = "memberPipeline"
  routing      = "routable"

  processing {
    processors {
      processor {
        type        = "fieldsAdd"
        id          = "add_team"
        description = "Tag records with the owning team"
        matcher     = "true"
        enabled     = true

        fields_add {
          fields {
            field {
              name  = "owning_team"
              value = "example-team"
            }
          }
        }
      }
    }
  }

  storage {
    processors {
      processor {
        type        = "bucketAssignment"
        id          = "assign_bucket"
        description = "Write to the team's Grail bucket"
        matcher     = "true"
        enabled     = true

        bucket_assignment {
          bucket_name = var.target_bucket
        }
      }
    }
  }
}

# 3. PIPELINE GROUP ---------------------------------------------------------
# composition is an ORDERED list. Entries before the placeholder run first,
# then whichever member pipeline the record was routed to, then entries after.
resource "dynatrace_openpipeline_v2_logs_pipelinegroups" "this" {
  display_name = "${var.name_prefix} group"

  composition {
    # Base pipeline runs before any member pipeline.
    pipeline_group_composition {
      is_pipeline_placeholder = false
      pipeline_id             = dynatrace_openpipeline_v2_logs_pipelines.base.id

      stages {
        type    = "include"
        include = ["processing"]
      }
    }

    # The slot where the routed member pipeline executes.
    pipeline_group_composition {
      is_pipeline_placeholder = true
    }
  }

  # Which stages members are allowed to define. Anything not included here is
  # ignored even if a member pipeline configures it.
  member_stages {
    type    = "include"
    include = ["processing", "storage"]
  }

  member_pipelines = [dynatrace_openpipeline_v2_logs_pipelines.member.id]
}

# 4. ROUTING ----------------------------------------------------------------
# !! This resource is a SINGLETON for the logs record type. Applying it
# !! replaces the ENTIRE logs routing table, including rules created in the UI.
# !! Every logs routing rule in the tenant must live in this one resource.
#
# Entries are evaluated top to bottom; the first matcher that hits wins, so the
# catch-all must be last.
resource "dynatrace_openpipeline_v2_logs_routing" "this" {
  routing_entries {
    routing_entry {
      enabled       = true
      description   = "Send example-team logs to the member pipeline"
      pipeline_type = "custom"
      pipeline_id   = dynatrace_openpipeline_v2_logs_pipelines.member.id
      matcher       = "matchesValue(k8s.namespace.name, \"example-team\")"
    }

    routing_entry {
      enabled             = true
      description         = "Catch-all: everything else keeps the built-in behaviour"
      pipeline_type       = "builtin"
      builtin_pipeline_id = "default"
      matcher             = "true"
    }
  }
}
