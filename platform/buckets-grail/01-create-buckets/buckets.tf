# One dynatrace_platform_bucket per entry in var.buckets.
#
# Safe edits, applied in place with no data loss and no bucket replacement:
#   - raise retention_days
#   - change display_name
#
# Anything that would delete the bucket stops the plan instead, because of
# prevent_destroy below. That covers the three ways a bucket can be destroyed:
#   - changing table or the bucket name (both force a replacement)
#   - removing an entry from var.buckets
#   - running `terraform destroy`
# A bucket's records are deleted with it and cannot be recovered.
#
# prevent_destroy must be a literal, so it cannot be turned into a variable. To
# remove a bucket deliberately, delete that line from this file first.
resource "dynatrace_platform_bucket" "this" {
  for_each = var.buckets

  name         = each.key
  table        = each.value.table
  retention    = each.value.retention_days
  display_name = each.value.display_name

  lifecycle {
    prevent_destroy = true
  }
}
