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

## Editing an existing bucket

Change `retention_days` or `display_name` in `terraform.tfvars`, then plan,
check, and apply:

```
terraform plan -out=tf.plan
./check-plan.sh tf.plan      # PowerShell: .\check-plan.ps1 tf.plan
terraform apply tf.plan
```

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

## Clean up

Test buckets only. See [Removing a test bucket](../README.md#removing-a-test-bucket)
— `prevent_destroy` makes a plain `terraform destroy` fail on purpose.
