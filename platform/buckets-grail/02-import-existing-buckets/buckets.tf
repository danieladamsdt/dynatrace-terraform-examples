# Adopt buckets that already exist, then manage them.
#
# The import block makes the first `terraform plan` attach the existing bucket
# to state instead of trying to create it. Nothing is created, changed, or
# deleted by an import. for_each in an import block needs Terraform >= 1.7.
#
# The first plan should show "will be imported" and NO changes to the bucket.
# If it shows a change, your tfvars differ from the live bucket — fix the
# tfvars, not the bucket. See the README.
import {
  for_each = var.existing_buckets

  to = dynatrace_platform_bucket.this[each.key]
  id = each.key # the import ID is the bucket name
}

resource "dynatrace_platform_bucket" "this" {
  for_each = var.existing_buckets

  name         = each.key
  table        = each.value.table
  retention    = each.value.retention_days
  display_name = each.value.display_name

  # Stops any plan that would delete a bucket and its data: a table or name
  # change, removing an entry, or `terraform destroy`. It must be a literal.
  lifecycle {
    prevent_destroy = true
  }
}
