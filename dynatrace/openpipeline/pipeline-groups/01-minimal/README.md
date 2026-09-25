# 01 — Minimal OpenPipeline group

The four objects in one file, with nothing abstracted away. Read
[`main.tf`](main.tf) top to bottom; it is commented as a walkthrough.

Creates: one base pipeline, one member pipeline, one pipeline group, and the
logs routing table.

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

### 2. Choose the Grail bucket

The member pipeline writes to `var.target_bucket`, which defaults to
`default_logs` — the built-in logs bucket, present on every tenant, so this
example applies as-is with nothing to replace.

To write somewhere else, **replace it with a bucket that already exists** in
the target tenant; `bucketAssignment` does not create one. Pass it on `plan`,
not `apply` — a saved plan file already has the value baked in and
`terraform apply tf.plan` rejects `-var`:

```
terraform plan -var="target_bucket=<existing-bucket>" -out=tf.plan
```

### 3. Apply

Identical on macOS, Linux, and Windows:

```
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

> **Applying this replaces the environment's entire logs routing table.** Use a
> throwaway environment, or export the existing table first — see
> [the routing section of the guide](../README.md#2-the-routing-table-is-a-singleton--read-this-before-your-first-apply).

Clean up with `terraform destroy`.
