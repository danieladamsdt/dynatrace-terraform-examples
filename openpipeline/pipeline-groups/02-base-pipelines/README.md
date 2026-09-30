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

`compositionPipeline` is the deprecated former name of this role. The provider
still accepts it, but use `basePipeline` — see
[migrating off `compositionPipeline`](../README.md#migrating-off-compositionpipeline).

Set your credentials first — see the
[guide's credentials section](../README.md#5-credentials-and-permissions) for
the bash/zsh, PowerShell, and Command Prompt forms.

Copy the example variables file (the only step whose syntax is
platform-specific), then edit it:

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
terraform apply
terraform output      # feed these IDs into ../03-app-pipelines
```

This stack creates **no routing table**, so applying it cannot disturb routing.

Deploy it once per Dynatrace environment, from the same configuration, so the
shared logic stays identical everywhere.
