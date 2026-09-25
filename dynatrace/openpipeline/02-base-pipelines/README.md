# 02 — Base pipelines (shared across environments)

Platform-team-owned logic that every member pipeline in a group is forced to
run. Deployed on its own so it can be changed without touching any team's
member pipeline or the routing table.

- `pre_member` — assigns `dt.security_context` and stamps provenance, before
  any team logic runs.
- `post_member` — assigns `dt.cost.costcenter` after team logic, so teams
  cannot skip cost attribution.

Both are `group_role = "basePipeline"` and `routing = "notRoutable"`: nothing
routes to them directly, they only execute as part of a group.

```
cp terraform.tfvars.example terraform.tfvars   # edit
terraform init && terraform apply
terraform output      # feed these IDs into ../03-app-pipelines
```

This stack creates **no routing table**, so applying it cannot disturb routing.

Deploy it once per Dynatrace environment, from the same configuration, so the
shared logic stays identical everywhere.
