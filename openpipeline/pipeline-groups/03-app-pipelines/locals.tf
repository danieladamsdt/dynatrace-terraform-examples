locals {
  # A pipeline only gets a processing stage if at least one processing-stage
  # option was supplied. An empty processing block is rejected by the provider
  # (processors requires at least one processor).
  needs_processing = {
    for key, app in var.applications : key => (
      app.drop_matcher != null || length(app.added_fields) > 0 || app.dql_script != null
    )
  }

  # Routing entries are evaluated in order and the first match wins, so the
  # order of this list is load-bearing. Zero-padding makes the lexicographic
  # sort agree with the numeric priority.
  app_keys_by_route_priority = [
    for entry in sort([
      for key, app in var.applications : format("%05d|%s", app.route_priority, key)
    ]) : split("|", entry)[1]
  ]
}
