# ---------------------------------------------------------------------------
# Base pipelines: shared, platform-team-owned logic that every member pipeline
# in a group is forced to run.
#
# These live in their own state on purpose. They change rarely, they are
# identical across environments, and keeping them separate means a fix here can
# be rolled out without touching any team's member pipelines or the routing
# table. Their IDs are exported and fed into the app stack as input.
# ---------------------------------------------------------------------------

# Runs BEFORE the member pipeline: normalize and classify while the record is
# still untouched by team-specific logic.
resource "dynatrace_openpipeline_v2_logs_pipelines" "pre_member" {
  display_name = "${var.name_prefix} base (pre-member)"
  custom_id    = "${var.name_prefix}-base-pre-member"
  group_role   = "basePipeline"
  routing      = "notRoutable"

  metadata_list {
    metadata {
      entry_key   = "managed-by"
      entry_value = "terraform"
    }
    metadata {
      entry_key   = "stack"
      entry_value = "02-base-pipelines"
    }
  }

  # Assign the security context first — it decides who can read the record.
  security_context {
    processors {
      processor {
        type        = "securityContext"
        id          = "set_security_context"
        description = "Derive dt.security_context from ${var.security_context_field}"
        matcher     = "true"
        enabled     = true

        # No default_value here: the provider schema marks it optional, but the
        # API rejects it for a field-typed securityContext value
        # ("defaultValue: Must be null"). Records missing the source field get
        # no security context rather than a fallback one.
        security_context {
          value {
            type = "field"

            field {
              source_field_name = var.security_context_field
            }
          }
        }
      }
    }
  }

  processing {
    processors {
      processor {
        type        = "fieldsAdd"
        id          = "stamp_provenance"
        description = "Record that this pipeline config is Terraform-managed"
        matcher     = "true"
        enabled     = true

        fields_add {
          fields {
            # Not "dt.openpipeline.managed_by": the dt.* namespace is reserved
            # and the API rejects writes to it ("name: Must not be modified").
            field {
              name  = "openpipeline.managed_by"
              value = "terraform"
            }
          }
        }
      }
    }
  }
}

# Runs AFTER the member pipeline: guardrails that teams must not be able to
# skip or undo, applied to whatever the member pipeline produced.
resource "dynatrace_openpipeline_v2_logs_pipelines" "post_member" {
  display_name = "${var.name_prefix} base (post-member)"
  custom_id    = "${var.name_prefix}-base-post-member"
  group_role   = "basePipeline"
  routing      = "notRoutable"

  metadata_list {
    metadata {
      entry_key   = "managed-by"
      entry_value = "terraform"
    }
    metadata {
      entry_key   = "stack"
      entry_value = "02-base-pipelines"
    }
  }

  cost_allocation {
    processors {
      processor {
        type        = "costAllocation"
        id          = "set_cost_center"
        description = "Derive dt.cost.costcenter from ${var.cost_center_field}"
        matcher     = "true"
        enabled     = true

        # Same API restriction as securityContext above: no default_value on a
        # field-typed costAllocation value.
        cost_allocation {
          value {
            type = "field"

            field {
              source_field_name = var.cost_center_field
            }
          }
        }
      }
    }
  }
}
