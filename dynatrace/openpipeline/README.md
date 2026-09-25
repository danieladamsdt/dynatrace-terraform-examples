# Dynatrace OpenPipeline

Terraform examples for configuring OpenPipeline — how records are routed,
processed, enriched, and stored on their way into Grail.

Each subdirectory covers one OpenPipeline topic and is self-contained. Start
with the topic you need; the shared background below applies to all of them.

## Topics

| Directory | Covers |
|---|---|
| [`pipeline-groups/`](pipeline-groups/) | Pipelines, pipeline groups, and routing. Object model, base vs. member pipelines, composition ordering, multi-stack layout, and the create/edit/delete lifecycle. |

Not covered yet — ingest sources (`*_ingestsources`) and data forwarding
(`*_dataforwarding`). See [adding an example](../../README.md#adding-an-example)
if you want to contribute one.

---

## Use the `v2` resources, not the originals

The provider carries two generations of OpenPipeline resources:

- **`dynatrace_openpipeline_v2_*`** — one settings object per pipeline, group,
  routing table, ingest source, or forwarding rule. **Use these.**
- **`dynatrace_openpipeline_*`** (no `v2`) — 12 resources backed by
  `/platform/openpipeline/v1/configurations/<type>`, each holding an entire
  configuration in a single object. The provider marks these
  **`Deprecated`** and its docs say to migrate to `dynatrace_openpipeline_v2_*`.

Everything in this directory uses `v2`.

## Resource naming

Every v2 resource follows one pattern:

```
dynatrace_openpipeline_v2_<record_type>_<kind>
```

All 13 record types support all 5 kinds, so any example here translates to
another record type by substituting the name — nothing else changes:

| | |
|---|---|
| **Record types** | `logs`, `metrics`, `spans`, `events`, `events_sdlc`, `events_security`, `bizevents`, `davis_events`, `davis_problems`, `security_events`, `system_events`, `user_events`, `usersessions` |
| **Kinds** | `pipelines`, `pipelinegroups`, `routing`, `ingestsources`, `dataforwarding` |

Examples in this directory use `logs`.

## Routing resources are singletons

`dynatrace_openpipeline_v2_<record_type>_routing` is **not one rule**. It is
the entire routing table for that record type in that environment. Applying it
replaces every routing rule of that type in the tenant, including rules created
in the UI and rules owned by another Terraform state or by Dynatrace
Configuration as Code (Monaco).

This is the single most destructive thing in this directory, and it applies to
all 13 record types. Before adopting an environment that already has
OpenPipeline configuration, export what exists.

The export utility is the provider binary itself, run directly. On Windows it
carries an `.exe` suffix:

```sh
# macOS / Linux
./terraform-provider-dynatrace -export dynatrace_openpipeline_v2_logs_routing
```

```powershell
# Windows — PowerShell
.\terraform-provider-dynatrace.exe -export dynatrace_openpipeline_v2_logs_routing
```

```bat
:: Windows — Command Prompt
terraform-provider-dynatrace.exe -export dynatrace_openpipeline_v2_logs_routing
```

The consequences and the safe adoption path are covered in
[`pipeline-groups/README.md`](pipeline-groups/README.md#2-the-routing-table-is-a-singleton--read-this-before-your-first-apply).

## Credentials

Shared by every example here. Set them in whichever shell you run Terraform
from; the `terraform` commands themselves are identical on macOS, Linux, and
Windows.

```sh
# macOS / Linux (bash, zsh) — also Git Bash and WSL on Windows
export DYNATRACE_ENV_URL="https://<env-id>.apps.dynatrace.com"
export DYNATRACE_PLATFORM_TOKEN="dt0s16.********"
```

```powershell
# Windows — PowerShell
$env:DYNATRACE_ENV_URL = "https://<env-id>.apps.dynatrace.com"
$env:DYNATRACE_PLATFORM_TOKEN = "dt0s16.********"
```

```bat
:: Windows — Command Prompt (no quotes: set would store them as part of the value)
set DYNATRACE_ENV_URL=https://<env-id>.apps.dynatrace.com
set DYNATRACE_PLATFORM_TOKEN=dt0s16.********
```

Required scopes: `settings:objects:read` and `settings:objects:write`.

Use a **platform token or OAuth client**, not a classic API token. Settings
objects created with a classic API token have an empty owner, which makes them
publicly readable and writable and puts them beyond the reach of
`dynatrace_settings_permissions`. If a classic API token is unavoidable, also
set `DYNATRACE_HTTP_OAUTH_PREFERENCE=true`.

## Reference

- [OpenPipeline documentation](https://docs.dynatrace.com/docs/platform/openpipeline)
- [Provider resource docs](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest/docs)
- [Supported resources](https://github.com/dynatrace-oss/terraform-provider-dynatrace/blob/main/documentation/supported-resources.md)

Resource names and schemas verified against **provider v1.105.0** via
`terraform providers schema -json`.
