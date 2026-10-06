# 02 — Ordered detection rules

Detection rules for an existing auto-injected frontend, with a guaranteed
order. Use this instead of `detection_rules` in
[`01-frontend`](../01-frontend/) when two rules can match the same URL and the
more specific one must win.

Creates: one `dynatrace_application_detection_rule_v2` per entry in
`detection_rules` (1 to 5), each placed directly after the one above it.

## Why this is a separate stack

Detection rules are one ordered list for the whole environment, and OneAgent
applies the first rule that matches. The provider orders rules with
`insert_after`. Tried against a live tenant:

- A rule with no `insert_after` is appended to the end of the list.
- Rules created by one `count` or `for_each` resource come out in a random
  order, with or without `-parallelism=1` (12 rules, shuffled both ways).
- Chaining instances of one resource fails at plan time with
  `Self-referential block`, although `terraform validate` passes.

The only deterministic option is one resource block per rule, each pointing at
the previous one. [`rules.tf`](rules.tf) has five such slots; a slot is created
only if you supply that many rules. For more, copy the last block.

### 1. Set credentials

This stack calls the platform REST API directly, so it reads its credentials
from Terraform variables rather than the `DYNATRACE_*` variables the other
examples use. Set them as `TF_VAR_*`:

```sh
# macOS / Linux (bash, zsh) — also Git Bash and WSL on Windows
export TF_VAR_dt_env_url="https://<env-id>.apps.dynatrace.com"
export TF_VAR_dt_platform_token="dt0s16.********"
```

```powershell
# Windows — PowerShell
$env:TF_VAR_dt_env_url = "https://<env-id>.apps.dynatrace.com"
$env:TF_VAR_dt_platform_token = "dt0s16.********"
```

```bat
:: Windows — Command Prompt (no quotes: set would store them as part of the value)
set TF_VAR_dt_env_url=https://<env-id>.apps.dynatrace.com
set TF_VAR_dt_platform_token=dt0s16.********
```

The token needs `settings:objects:read` and `settings:objects:write`.

### 2. Fill in the variables

```sh
# macOS / Linux, Git Bash, WSL
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

`frontend_name` is the `frontend.name` of a frontend that already exists.
Put the most specific rule first.

### 3. Apply

```
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

## Placing the block among existing rules

By default the whole block is appended to the end of the list. To put it after
a specific existing rule, set `insert_after` to that rule's settings object ID.
Find IDs with the Settings API, or `dtctl get settings --schema
builtin:rum.web.app-detection`.

## Editing the list later

Inserting or removing a rule in the middle moves every rule below it to a
different slot, so Terraform updates those slots in place. Because each slot
points at the one above it, the result stays in the order you wrote.

## Notes

- `data.http.entity` records its request header — your token — in state.
  State is gitignored; treat it as a secret.
- Rules need the entity ID (`APPLICATION-…`), not the `FRONTEND-…` ID the
  Gen3 API returns. This stack looks it up by `frontend.name`.

Verified against `dynatrace-oss/dynatrace` v1.105.0, `hashicorp/http` v3.6.2,
Terraform 1.16.
