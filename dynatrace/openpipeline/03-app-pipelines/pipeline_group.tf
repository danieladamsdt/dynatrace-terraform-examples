# ---------------------------------------------------------------------------
# The pipeline group binds base pipelines and member pipelines together.
#
# composition is an ORDERED list. The block order below is the execution order:
#   pre-member base pipelines -> placeholder (routed member pipeline) -> post-member
# ---------------------------------------------------------------------------

resource "dynatrace_openpipeline_v2_logs_pipelinegroups" "this" {
  display_name = "${var.pipeline_group_name} (${var.environment_name})"

  composition {
    dynamic "pipeline_group_composition" {
      for_each = var.pre_member_base_pipeline_ids

      content {
        is_pipeline_placeholder = false
        pipeline_id             = pipeline_group_composition.value

        stages {
          type    = "include"
          include = var.base_pipeline_stages
        }
      }
    }

    # Exactly one placeholder: the slot where the routed member pipeline runs.
    pipeline_group_composition {
      is_pipeline_placeholder = true
    }

    dynamic "pipeline_group_composition" {
      for_each = var.post_member_base_pipeline_ids

      content {
        is_pipeline_placeholder = false
        pipeline_id             = pipeline_group_composition.value

        stages {
          type    = "include"
          include = var.base_pipeline_stages
        }
      }
    }
  }

  member_stages {
    type    = var.member_stages.type
    include = var.member_stages.include
    exclude = var.member_stages.exclude
  }

  # Adding an application to var.applications adds it here automatically.
  # This is the step that is easiest to forget when done by hand.
  member_pipelines = [for pipeline in dynatrace_openpipeline_v2_logs_pipelines.member : pipeline.id]
}
