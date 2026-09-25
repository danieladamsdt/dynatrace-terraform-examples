# OpenPipeline pipeline groups, pipelines, and routing in Terraform

How to manage Dynatrace OpenPipeline with the `dynatrace-oss/dynatrace` provider:
what the objects are, how they reference each other, how to lay the stacks out,
and how to create, change, and delete them safely.

Examples here use **logs**. Every other record type works identically — swap
`logs` for `events`, `bizevents`, `spans`, `metrics`, `davis_problems`,
`security_events`, `usersessions`, and so on in the resource names.

---

## 1. The object model

Four settings objects, three of which you write by hand:

| Object | Resource | Cardinality |
|---|---|---|
| Pipeline | `dynatrace_openpipeline_v2_logs_pipelines` | one per pipeline |
| Pipeline group | `dynatrace_openpipeline_v2_logs_pipelinegroups` | one per group |
| Routing table | `dynatrace_openpipeline_v2_logs_routing` | **one per environment** |
| Ingest sources | `dynatrace_openpipeline_v2_logs_ingestsources` | out of scope here |

A pipeline's `group_role` decides what it is:

- **`basePipeline`** — platform-owned logic every member of a group must run.
  Set `routing = "notRoutable"`: nothing routes to it directly, it only ever
  executes as part of a group.
- **`memberPipeline`** — team-owned logic for one application. Set
  `routing = "routable"` so routing rules can target it.
- **`compositionPipeline`** — a pipeline referenced from a group's composition
  that is not a reusable base pipeline.

### How they reference each other

```
routing table ──targets──> member pipeline ──member of──> pipeline group
                                                               │
                                                     composition references
                                                               ▼
                                                        base pipelines
```

Both references use the **settings object ID** (the `.id` attribute), not
`custom_id` and not the display name. In Terraform, always reference
`dynatrace_openpipeline_v2_logs_pipelines.<name>.id` so the dependency graph
knows the real ordering.

### Composition and the placeholder

`composition` is an **ordered list**. Exactly one entry has
`is_pipeline_placeholder = true`; it marks where the routed member pipeline
runs. Entries above it execute first, entries below execute after:

```
pre-member base pipelines  ->  [ routed member pipeline ]  ->  post-member base pipelines
```

`member_stages` restricts which stages a member pipeline may define. A stage
left out of `member_stages` is ignored even if a team configures it — this is
the guardrail that stops a team reassigning its own `dt.security_context` or
skipping cost allocation.

Order in HCL is source order, including across `dynamic` blocks, so
`dynamic (pre) → static placeholder → dynamic (post)` gives a deterministic
composition. See [`03-app-pipelines/pipeline_group.tf`](03-app-pipelines/pipeline_group.tf).

---

## 2. The routing table is a singleton — read this before your first apply

`dynatrace_openpipeline_v2_logs_routing` is **not one rule**. It is the entire
logs routing table for the environment. Applying it **replaces every logs
routing rule in the tenant**, including rules created in the UI and rules
managed by another Terraform state or by Monaco.

Three consequences:

1. **One owner per environment.** All logs routing for one Dynatrace
   environment must live in exactly one state file. Split across two stacks,
   whichever applies last silently deletes the other's rules.
2. **Export before you adopt.** On an environment that already has routing,
   capture it first:
   ```
   terraform-provider-dynatrace -export dynatrace_openpipeline_v2_logs_routing
   ```
3. **Always end with a catch-all.** Entries are evaluated top to bottom and the
   first matcher that hits wins. Without a final `matcher = "true"` entry
   pointing at the `default` built-in pipeline, unmatched records are dropped.

Rule order is therefore load-bearing. These examples make it explicit with a
`route_priority` per application rather than relying on map iteration order,
and a variable `validation` block rejects duplicate priorities.

`pipeline_id` is only valid when `pipeline_type = "custom"`. For
`pipeline_type = "builtin"` use `builtin_pipeline_id`.

---

## 3. Stack layout

The examples are three separate stacks, read in order:

| Directory | What it is |
|---|---|
| [`01-minimal/`](01-minimal/) | One base pipeline, one member pipeline, one group, one routing table, in a single file. Start here to see the shapes. |
| [`02-base-pipelines/`](02-base-pipelines/) | Base pipelines only. Shared across all environments, own state, own lifecycle. |
| [`03-app-pipelines/`](03-app-pipelines/) | Member pipelines + group + routing for one environment, driven by a single `applications` map. The template to copy. |

### Why base pipelines get their own state

Base pipelines change rarely and are usually identical across dev/staging/prod.
Keeping them in a separate stack means a fix to shared logic ships without
touching any team's member pipeline or the routing table — a much smaller blast
radius. Member pipelines, groups, and routing are environment-specific (each
environment monitors different applications), so they deploy together, once per
environment.

### Wiring the two stacks together

The provider exposes **no data source** for OpenPipeline settings objects
(verified against provider v1.105 — `terraform providers schema -json` lists
zero `openpipeline` data sources). So the base pipeline IDs cross the boundary
as explicit input. Either paste the outputs:

```hcl
# 03-app-pipelines/terraform.tfvars
pre_member_base_pipeline_ids  = ["vu9U3hXa3q0AAAAB..."]
post_member_base_pipeline_ids = ["vu9U3hXa3q0AAAAB..."]
```

…or read them from the base stack's remote state:

```hcl
data "terraform_remote_state" "base" {
  backend = "s3"
  config  = { bucket = "tfstate", key = "dynatrace/openpipeline/base", region = "us-east-1" }
}

# then pass into the group:
#   pre_member_base_pipeline_ids = [data.terraform_remote_state.base.outputs.pre_member_base_pipeline_id]
```

Pasting IDs is deliberate in the examples: it keeps them backend-agnostic, and
it means the app stack cannot be broken by an unrelated change in the base
stack. Remote state is the better choice once the pairing is stable.

---

## 4. Lifecycle

### Onboarding an application

Done by hand this is three steps that must stay in sync: create the pipeline,
add it to the group, add a routing rule. Forgetting step two is the common
failure — the pipeline receives records but the group's base logic never runs.

In [`03-app-pipelines/`](03-app-pipelines/) it is **one** step, because the
group membership and the routing rule are both derived from the same map:

```hcl
applications = {
  "checkout-api" = {
    display_name   = "Checkout API logs"
    route_priority = 100
    route_matcher  = "matchesValue(k8s.namespace.name, \"checkout\")"
    bucket_name    = "logs_checkout"
    added_fields   = { owning_team = "payments" }
  }
}
```

```
terraform plan -out=tf.plan    # review, then
terraform apply tf.plan
```

Expect three changes: one pipeline created, the group's `member_pipelines`
updated, the routing table updated.

### Editing a pipeline

Change the map entry and apply. Three pipeline fields are marked `ForceNew` in
the provider and cannot be updated in place — `custom_id`, `group_role`, and
`routing` (provider v1.91.0) — so changing any of them replaces the object.
Because the map key becomes `custom_id`, **renaming a map key destroys and
recreates the pipeline**, which changes its settings object ID and therefore rewrites the
group membership and routing rule too. If you only want a new label, change
`display_name` and leave the key alone.

To rename the key without a gap in processing, `terraform state mv` first:

```
terraform state mv \
  'dynatrace_openpipeline_v2_logs_pipelines.member["old-key"]' \
  'dynatrace_openpipeline_v2_logs_pipelines.member["new-key"]'
```

…then update the map. (This still replaces the object if `custom_id` differs;
it only avoids a destroy/create of unrelated resources.)

### Deleting an application

Remove its entry from `applications` and apply. Order matters, and Terraform
gets it right on its own **only because the group and routing reference the
pipeline through `.id`**: the routing table and group membership are updated
before the pipeline is destroyed. A pipeline still referenced by a group or a
routing rule cannot be deleted.

If you ever hardcode an ID instead of referencing the resource, you lose that
edge in the dependency graph and the destroy fails with a reference error. Fix
it by removing the reference and applying, then destroying the pipeline.

### Tearing down the whole group

```
cd 03-app-pipelines && terraform destroy   # members, group, routing
cd ../02-base-pipelines && terraform destroy
```

Destroying the routing resource removes the managed table. Make sure you know
what the environment falls back to before doing this in production.

---

## 5. Credentials and permissions

```
export DYNATRACE_ENV_URL="https://<env-id>.apps.dynatrace.com"
export DYNATRACE_PLATFORM_TOKEN="dt0s16.********"
```

Required scopes: `settings:objects:read` and `settings:objects:write`.

**Use a platform token or OAuth client, not a classic API token.** A settings
object created with a classic API token has an empty owner, which means:

- the object is public — anyone with settings permissions can read and modify it;
- `dynatrace_settings_permissions` cannot restrict it afterwards.

If a classic API token is unavoidable, also set
`DYNATRACE_HTTP_OAUTH_PREFERENCE=true`.

---

## 6. Adopting an environment that already has OpenPipeline config

Export what exists before writing any HCL:

```
terraform-provider-dynatrace -export dynatrace_openpipeline_v2_logs_pipelines
terraform-provider-dynatrace -export dynatrace_openpipeline_v2_logs_pipelinegroups
terraform-provider-dynatrace -export dynatrace_openpipeline_v2_logs_routing
```

Then `terraform import` each object by its settings object ID, and confirm
`terraform plan` is empty before changing anything. The routing table is the
one that punishes you for skipping this step.

---

## 7. Gotchas

- **Empty stage blocks are rejected.** A `processing {}` block requires at least
  one processor. Use a `dynamic` block so the stage is omitted entirely when a
  pipeline has nothing to do — see `local.needs_processing` in
  [`03-app-pipelines/locals.tf`](03-app-pipelines/locals.tf).
- **Processor `id` must be unique within a stage** and is referenced in the UI.
  Keep it stable and descriptive.
- **`matcher` is DQL.** Inside HCL, `"` must be escaped: `matchesValue(k8s.namespace.name, \"checkout\")`.
- **Buckets must already exist.** `bucketAssignment` does not create the Grail
  bucket. Manage it with `dynatrace_grail_storage_bucket` or expect an apply error.
- **Assign `dt.security_context` in a base pipeline**, before the member
  placeholder, and exclude `securityContext` from `member_stages`. Otherwise a
  team can widen access to its own data.
- **Drop early.** A `drop` processor at the top of the processing stage keeps
  noise out of metric extraction and billing.

---

## 8. Reference

- [OpenPipeline documentation](https://docs.dynatrace.com/docs/platform/openpipeline)
- [Pipeline groups](https://docs.dynatrace.com/docs/shortlink/openpipeline-pipeline-groups)
- [Provider resource docs](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs)
- [Supported resources](https://github.com/dynatrace-oss/terraform-provider-dynatrace/blob/main/documentation/supported-resources.md)

Schemas in these examples were verified against **provider v1.105.0** with
`terraform providers schema -json`.
