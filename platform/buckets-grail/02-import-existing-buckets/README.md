# 02 — Adopt existing buckets, then edit them safely

For buckets that already exist in the tenant — created in the UI, with the API,
or by another tool. An `import` block attaches each one to Terraform state
without creating, changing, or deleting anything. After that they are edited
exactly as in [01](../01-create-buckets/README.md#editing-an-existing-bucket).

Read the guarantees and the retention caveat in the
[parent README](../README.md#what-can-and-cannot-change) first.

Files: [`buckets.tf`](buckets.tf) holds the `import` block and the resource.

Needs Terraform >= 1.7 (`for_each` in an `import` block). The other stacks
need only >= 1.5. Verified against provider 1.105.0 on a bucket created outside
Terraform: the import plan showed `1 to import, 0 to add, 0 to change, 0 to
destroy`, and a plan after the import showed no drift.

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

### 2. Describe the buckets as they are today

Read each bucket's current table, retention, and display name:

```
dtctl get buckets
```

or open the Grail bucket management UI. Then:

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

Edit `terraform.tfvars` so every value **matches the live bucket**. Do not
change anything yet — adopt first, edit second.

### 3. Import

```
terraform init
terraform plan -out=tf.plan && ./check-plan.sh tf.plan
```

The plan must say `1 to import, 0 to add, 0 to change, 0 to destroy` (the
first number is your bucket count). Then:

```
terraform apply tf.plan
```

If the plan shows a **change**, your `terraform.tfvars` differs from the live
bucket. Fix the file, not the bucket. Two cases to watch:

- **Omitting `display_name`** shows `"Legacy app logs" -> null` and applying it
  clears the label. Set it to the current value.
- **A lower `retention_days` than the live bucket** is planned as an import plus
  an update (`1 to import, 1 to change`). `check-plan` flags it (tested), and
  applying it would shorten the live bucket's retention. Match the live value.
- **A wrong `table`** shows `forces replacement` and the plan fails with
  `Instance cannot be destroyed`. Correct the table.

- **A misspelled bucket name** fails with `Cannot import non-existent remote
  object`. Nothing is created.
- **Quote hyphenated names** in `terraform.tfvars` (`"logs_trading-desk" = {`).
  Hyphens and a display name with an apostrophe both imported fine.

An import with matching values changes nothing, so it is safe to run on a
production bucket. Tested on a bucket holding live logs: the records were
identical before and after the import and after raising retention.

## Editing afterward

Change `retention_days` or `display_name`, then run the same
plan, check, apply sequence. Raising 30 to 45 days showed `~ retention = 30 ->
45`, `0 to destroy`, and the bucket kept its name and table.

You can remove the `import` block after the first successful apply. Leaving it
is harmless, and it lets the same file adopt a bucket that was missed.

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
and never contact Dynatrace. On an import, run the check after the plan and before the apply, as above:

```sh
terraform plan -out=tf.plan && ./check-plan.sh tf.plan && terraform apply tf.plan
```

```powershell
terraform plan -out=tf.plan; if ($?) { .\check-plan.ps1 tf.plan; if ($?) { terraform apply tf.plan } }
```

Exit 1 means an unsafe plan; exit 2 means the check could not run (no `jq`, no
plan file, or the plan itself errored). Either way, do not apply. If you really
mean to shorten retention, apply the plan without the check after reading it.

## Stop managing a bucket without deleting it

```
terraform state rm 'dynatrace_platform_bucket.this["<bucket-name>"]'
```

Then delete its entry from `terraform.tfvars`. The bucket and its data stay in
the tenant (tested: the retention and all records were unchanged). If you leave
the entry in place, the next plan imports the bucket again.
