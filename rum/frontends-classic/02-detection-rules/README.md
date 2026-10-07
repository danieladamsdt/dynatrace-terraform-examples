# 02 — Ordered detection rules

Detection rules for an existing auto-injected frontend, with a guaranteed
order. The most specific rule goes first.

Creates: one `dynatrace_application_detection_rule_v2` per entry in
`detection_rules` (1 to 5), each placed directly after the one above it.

## Why the rules are written out as separate resources

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

The token needs `settings:objects:read` and `settings:objects:write`.

### 1. Set credentials

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

`frontend_name` is the `frontend.name` of an existing **auto-injected**
frontend. The stack looks up its entity ID itself. Detection rules do not apply
to agentless or mobile frontends; pointing the stack at a mobile frontend fails
the plan with an explanation.

### 3. Apply

Identical on macOS, Linux, and Windows:

```
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

## Placing the block among existing rules

By default the whole block is appended to the end of the environment-wide list,
below every rule that already exists. To put it after a specific rule, set
`insert_after` to that rule's settings object ID:

```
dtctl get settings --schema builtin:rum.web.app-detection
```

## Editing the list later

Inserting a rule in the middle moves every rule below it to a different slot,
so Terraform updates those slots in place and creates one more at the end. Each
slot points at the one above it, so the result stays in the order you wrote.

## Notes

- Don't use this stack and another configuration that also writes rules for the
  same frontend: both would create rules and you would get duplicates.

Verified against `dynatrace-oss/dynatrace` v1.105.0, Terraform 1.16: four rules
created in order, a clean second plan, and a rule inserted mid-list kept the order.
