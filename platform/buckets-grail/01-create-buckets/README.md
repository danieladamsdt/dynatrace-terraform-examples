# 01 — Create buckets, then edit them safely

Creates one custom Grail bucket per entry in `var.buckets`. The example file
defines four, one per table type: `logs`, `spans`, `events`, `bizevents`.
Read the guarantees and the retention caveat in the
[parent README](../README.md#what-can-and-cannot-change) first.

Files: [`buckets.tf`](buckets.tf) is the whole example;
[`check-plan.sh`](check-plan.sh) / [`check-plan.ps1`](check-plan.ps1) are the
plan checks.

Verified against provider 1.105.0: apply, a second plan with no drift, in-place
edits, and each blocked deletion below.

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

The token needs `storage:bucket-definitions:read` and
`storage:bucket-definitions:write`.

### 2. Define your buckets

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

Edit `terraform.tfvars`. The map key is the bucket name and cannot be renamed
later. Names in the example file are placeholders.

### 3. Create

Identical on macOS, Linux, and Windows:

```
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

The apply blocks on each bucket for about a minute while it activates; buckets
are created in parallel. A bucket can still read `creating` for a moment after
the apply finishes, so before pointing anything at a new bucket, confirm it is
`active` — see [the activation note](../README.md#pitfalls).

## Editing an existing bucket

Change `retention_days` or `display_name` in `terraform.tfvars`, then plan,
check, and apply. [Why the check?](#what-check-plan-is-for)

```
terraform plan -out=tf.plan && ./check-plan.sh tf.plan && terraform apply tf.plan
```

Keep `display_name` in every entry you edit: leaving it out clears the label.
A safe edit reads `1 to change, 0 to destroy` and `~ retention = 35 -> 60`.
The bucket is updated in place: same bucket, same data.

Things that are refused, so you cannot do them by accident:

| You change | Result |
|---|---|
| `table` | plan fails: `forces replacement`, then `Instance cannot be destroyed` |
| a bucket's map key (rename) | plan fails: `Instance cannot be destroyed` |
| delete an entry from `buckets` | plan fails: `Instance cannot be destroyed` |
| `terraform destroy` | fails: `Instance cannot be destroyed` |
| `retention_days` **lower** | **plan succeeds**; `check-plan.sh` exits 1 |

## What `check-plan` is for

Terraform's own plan cannot tell you that a change will delete data. Lowering
`retention_days` is shown as a harmless in-place update (`1 to change, 0 to
destroy`), yet Grail then deletes every record older than the new value. The
`check-plan.sh` (macOS, Linux, Git Bash, WSL; needs `jq`) and `check-plan.ps1`
(PowerShell) scripts read a saved plan and stop you before the apply when it
would:

- shorten a bucket's retention, or
- delete or replace a bucket.

They print the bucket and the change, and exit non-zero. They change nothing
and never contact Dynatrace. Chain them between plan and apply so a failure
stops the apply:

```sh
terraform plan -out=tf.plan && ./check-plan.sh tf.plan && terraform apply tf.plan
```

```powershell
terraform plan -out=tf.plan; if ($?) { .\check-plan.ps1 tf.plan; if ($?) { terraform apply tf.plan } }
```

Exit 1 means an unsafe plan; exit 2 means the check could not run (no `jq`, no
plan file, or the plan itself errored). Either way, do not apply. If you really
mean to shorten retention, apply the plan without the check after reading it.

## Clean up

Test buckets only. See [Removing a test bucket](../README.md#removing-a-test-bucket)
— `prevent_destroy` makes a plain `terraform destroy` fail on purpose.
