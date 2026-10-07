output "buckets" {
  description = "Managed buckets, keyed by bucket name: table, retention in days, display name, and status."
  value = {
    for name, b in dynatrace_platform_bucket.this : name => {
      table          = b.table
      retention_days = b.retention
      display_name   = b.display_name
      status         = b.status
    }
  }
}
