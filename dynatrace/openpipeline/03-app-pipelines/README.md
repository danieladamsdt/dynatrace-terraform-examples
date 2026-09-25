# 03 — Application pipelines, group, and routing (per environment)

The template to copy. One environment's member pipelines, the pipeline group
that binds them to the base pipelines, and the routing table — all derived from
a single `applications` map in [`terraform.tfvars.example`](terraform.tfvars.example).

Onboarding an application is one map entry instead of three hand-maintained
objects:

```hcl
applications = {
  "checkout-api" = {
    display_name   = "Checkout API logs"
    route_priority = 100
    route_matcher  = "matchesValue(k8s.namespace.name, \"checkout\")"
    bucket_name    = "logs_checkout"
    added_fields   = { owning_team = "payments" }
    drop_matcher   = "matchesPhrase(content, \"health check\")"
  }
}
```

| File | Contents |
|---|---|
| [`pipelines.tf`](pipelines.tf) | One member pipeline per application, optional processors via `dynamic` blocks |
| [`pipeline_group.tf`](pipeline_group.tf) | Composition ordering and `member_stages` guardrails |
| [`routing.tf`](routing.tf) | The singleton routing table, priority-ordered, catch-all last |
| [`locals.tf`](locals.tf) | Routing order and "does this pipeline need a processing stage" |

```
cp terraform.tfvars.example terraform.tfvars   # edit, incl. base pipeline IDs from ../02-base-pipelines
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

> **`terraform apply` here rewrites the environment's whole logs routing
> table.** All logs routing for the environment must be owned by this one
> state. See [the guide](../README.md#2-the-routing-table-is-a-singleton--read-this-before-your-first-apply).

Deploy one copy per Dynatrace environment — separate state (workspace, backend
key, or directory) and its own `terraform.tfvars`, since each environment
monitors different applications.

Map keys become `custom_id`, which is `ForceNew`: renaming a key destroys and
recreates the pipeline. See the lifecycle section of the guide.
