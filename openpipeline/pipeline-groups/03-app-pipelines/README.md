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
    bucket_name    = "logs_checkout" # must already exist in the tenant
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

Set your credentials first — see the
[guide's credentials section](../README.md#5-credentials-and-permissions) for
the bash/zsh, PowerShell, and Command Prompt forms.

Copy the example variables file (the only step whose syntax is
platform-specific), then edit it. Two things must be replaced with real values
from your tenant:

- **`pre_member_base_pipeline_ids` / `post_member_base_pipeline_ids`** — the
  placeholder IDs must be swapped for `terraform output` from
  [`../02-base-pipelines`](../02-base-pipelines/).
- **`bucket_name`** per application — commented out by default, so the file
  applies cleanly as shipped. Uncomment it only once you know the name of a
  Grail bucket that **already exists** in the target tenant; nothing here
  creates one, and a wrong name fails partway through the apply.

```sh
# macOS / Linux
cp terraform.tfvars.example terraform.tfvars
```

```powershell
# Windows — PowerShell
Copy-Item terraform.tfvars.example terraform.tfvars
```

```bat
:: Windows — Command Prompt
copy terraform.tfvars.example terraform.tfvars
```

Then, identically on every platform:

```
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
