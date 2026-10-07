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
terraform plan -out=tf.plan
./check-plan.sh tf.plan      # PowerShell: .\check-plan.ps1 tf.plan
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
- **A wrong `table`** shows `forces replacement` and the plan fails with
  `Instance cannot be destroyed`. Correct the table.

An import with matching values changes nothing, so it is safe to run on a
production bucket.

## Editing afterward

Change `retention_days` or `display_name`, then run the same
plan, check, apply sequence. Raising 30 to 45 days showed `~ retention = 30 ->
45`, `0 to destroy`, and the bucket kept its name and table.

You can remove the `import` block after the first successful apply. Leaving it
is harmless, and it lets the same file adopt a bucket that was missed.

## Stop managing a bucket without deleting it

```
terraform state rm 'dynatrace_platform_bucket.this["<bucket-name>"]'
```

Then delete its entry from `terraform.tfvars`. The bucket and its data stay in
the tenant.
