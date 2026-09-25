# ---------------------------------------------------------------------------
# Member pipelines — one per onboarded application.
#
# routable = "routable" is what makes a pipeline a valid target for a routing
# rule. Base pipelines are notRoutable; they only ever run via a group.
# ---------------------------------------------------------------------------

resource "dynatrace_openpipeline_v2_logs_pipelines" "member" {
  for_each = var.applications

  display_name = "${each.value.display_name} (${var.environment_name})"
  custom_id    = each.key
  group_role   = "memberPipeline"
  routing      = "routable"

  metadata_list {
    metadata {
      entry_key   = "managed-by"
      entry_value = "terraform"
    }
    metadata {
      entry_key   = "application"
      entry_value = each.key
    }
    metadata {
      entry_key   = "environment"
      entry_value = var.environment_name
    }
  }

  dynamic "processing" {
    for_each = local.needs_processing[each.key] ? [1] : []

    content {
      processors {
        # Dropping first keeps noise out of everything downstream, including
        # metric extraction and billing.
        dynamic "processor" {
          for_each = each.value.drop_matcher == null ? [] : [each.value.drop_matcher]

          content {
            type        = "drop"
            id          = "drop_noise"
            description = "Drop records matching the configured noise filter"
            matcher     = processor.value
            enabled     = true
          }
        }

        dynamic "processor" {
          for_each = length(each.value.added_fields) == 0 ? [] : [each.value.added_fields]

          content {
            type        = "fieldsAdd"
            id          = "add_static_fields"
            description = "Add the application's static fields"
            matcher     = "true"
            enabled     = true

            fields_add {
              fields {
                dynamic "field" {
                  for_each = processor.value

                  content {
                    name  = field.key
                    value = field.value
                  }
                }
              }
            }
          }
        }

        dynamic "processor" {
          for_each = each.value.dql_script == null ? [] : [each.value.dql_script]

          content {
            type        = "dql"
            id          = "custom_dql"
            description = "Application-specific DQL transformation"
            matcher     = "true"
            enabled     = true

            dql {
              script = processor.value
            }
          }
        }
      }
    }
  }

  dynamic "storage" {
    for_each = each.value.bucket_name == null ? [] : [each.value.bucket_name]

    content {
      processors {
        processor {
          type        = "bucketAssignment"
          id          = "assign_bucket"
          description = "Store in the application's Grail bucket"
          matcher     = "true"
          enabled     = true

          bucket_assignment {
            bucket_name = storage.value
          }
        }
      }
    }
  }
}
