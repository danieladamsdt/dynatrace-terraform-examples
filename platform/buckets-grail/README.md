# Grail buckets in Terraform

Create custom Grail buckets and edit them afterward, using the
`dynatrace_platform_bucket` resource from the `dynatrace-oss/dynatrace`
provider. Nothing else is needed — no other provider.

The goal of these examples is that **editing an existing bucket can never delete
the bucket or its data**. That is achievable with one exception, described next.

Verified against provider `dynatrace-oss/dynatrace` 1.105.0 on a live tenant.

| Directory | What it shows |
|---|---|
| [`01-create-buckets/`](01-create-buckets/) | Create buckets for each table type from a map, then edit them safely |
| [`02-import-existing-buckets/`](02-import-existing-buckets/) | Bring buckets that already exist (created in the UI or API) under Terraform, then edit them safely |

## What can and cannot change

| Setting | Edit in place? | Risk |
|---|---|---|
| `retention` — increase | Yes | None. Data is kept longer. |
| `retention` — **decrease** | Yes | **Deletes records older than the new value.** Not reversible. |
| `display_name` | Yes | None. **Leaving it out of the config clears the label** (`"Name" -> null`). |
| `name` | **No** — forces replacement | Deleting the bucket deletes its data |
| `table` | **No** — forces replacement | Deleting the bucket deletes its data |

The provider has no other mutable setting; Grail itself locks the name and table
after creation. The resource supports only the `logs`, `spans`, `events`, and
`bizevents` tables. Buckets for other tables (metrics, `user.events`,
`security.events`, and so on) cannot be managed with it.

## The two guards

**1. `prevent_destroy = true` blocks every route to deleting a bucket.** Each
stack sets it on the bucket resource. Terraform then fails the *plan* — before
anything is sent to Dynatrace — for each of:

- changing `table` or the bucket name (a replacement is a destroy followed by a
  create)
- removing a bucket from the configuration
- `terraform destroy`

The error is `Instance cannot be destroyed`. All four were tested live. It fails
the **whole plan**, not just that bucket, so one blocked deletion also holds up
unrelated edits in the same stack until it is resolved.
`prevent_destroy` must be a literal in the `.tf` file; Terraform does not allow a
variable there, so removing a bucket on purpose means editing that line.

**2. A retention decrease needs a plan check.** Lowering retention is an
ordinary in-place update to Terraform: the plan reads `retention = 60 -> 35`
with `0 to destroy`, `prevent_destroy` does not fire, and the apply succeeds
without a prompt. Grail then deletes the older records, which can take days.
Each stack ships `check-plan.sh` (needs `jq`) and `check-plan.ps1`; both read the
saved plan and exit non-zero if a bucket would be deleted or its retention
shortened. They only read the plan file; they change nothing and never contact
Dynatrace. Exit 1 means unsafe; exit 2 means the check could not run (no `jq`,
no plan file, or an errored plan). Never apply after either:

```sh
terraform plan -out=tf.plan && ./check-plan.sh tf.plan && terraform apply tf.plan
```

```powershell
terraform plan -out=tf.plan; if ($?) { .\check-plan.ps1 tf.plan; if ($?) { terraform apply tf.plan } }
```

`check-plan.sh` was tested on macOS. `check-plan.ps1` follows the same logic but
was **not** run, because PowerShell was not available where this was written.
Run it once against a plan that lowers retention before relying on it.

Plan normally. `terraform plan -refresh=false` compares against stale state, so
a retention value changed in the UI would not show up in the plan or the check.

If you do mean to shorten retention, review the plan, accept that data older
than the new value will be deleted, and apply without the check.

## Pitfalls

- **A stale `terraform.tfvars` shortens retention.** Terraform applies the value
  in the file, whatever the bucket currently has. If someone raised retention in
  the UI and your file still says the old number, the next apply lowers it again.
  Run `terraform plan` and read it before every apply, and keep the file in
  version control so it is the source of truth.
- **Retention drops are not blocked by `prevent_destroy`.** See guard 2.
- **Terraform is slow to create buckets.** One bucket took about a minute to
  create; buckets in one stack are created in parallel.
- **Bucket status lags `apply`.** Creating a bucket took about a minute in
  testing, and the live status was still `creating` just after `apply`
  reported success. Edits are asynchronous too: a bucket reports `updating`, and
  a read right after `apply` can show the previous value. Back-to-back applies
  (create, then three edits in a row) all succeeded and converged on the last
  value, so the stacks need no wait logic. Anything that **uses** a new bucket
  immediately, such as an OpenPipeline `bucketAssignment` or ingest, can still
  race the activation. The provider has no bucket data source to wait on, so
  apply the buckets first, confirm `active` (`dtctl get buckets`), then apply
  what depends on them. Not tested: a downstream resource created in the same
  apply.
- **Deleting a bucket is asynchronous** and can take a long time on a large
  bucket. The `terraform destroy` flow below is only for test buckets.
- **Limits.** Retention is 1 to 3657 days (the stacks reject anything else at
  plan time). Bucket names are 3 to 100
  characters, start with a lowercase letter, and use only lowercase letters,
  digits, underscores, and hyphens. A tenant has 80 custom buckets by default.
- **Only custom buckets are safe to adopt.** Many `default_*` buckets report
  `updatable: false` and cannot be edited, and the examples were only tested on
  custom buckets. Importing a built-in bucket was not tested; do not.
- **Do not trust the `records` count from `dtctl get buckets`.** It read `0`
  for a bucket that held logs. To check what a bucket holds, query it:
  `fetch logs, from:now()-10d | filter dt.system.bucket == "<bucket-name>" | summarize count()`.
  Take a count (and, for a real bucket, a copy of the records) before any
  retention change, and compare afterward.
- **The token needs the bucket-definition scopes.** Use a platform token with
  `storage:bucket-definitions:read` and `storage:bucket-definitions:write`. A
  classic API token cannot manage buckets. Without the scopes every call fails
  with `Required permissions not met`.

## Removing a test bucket

Throwaway buckets only — this deletes the data, and deletion is asynchronous:
`terraform destroy` took a couple of minutes for a few empty buckets.

1. In `buckets.tf`, delete the `prevent_destroy = true` line (or set it to
   `false`). This is a configuration setting, so no apply is needed first.
2. Run `terraform destroy`.
3. Restore the line.

To stop managing a bucket **without deleting it**, run
`terraform state rm 'dynatrace_platform_bucket.this["<bucket-name>"]'`, then
remove its entry from the variable file. Tested: the bucket and its records were
untouched. If you skip the second step, the next plan imports the bucket again
(stack 02) or tries to create it (stack 01, which fails because the name
exists).

## Reading a bucket's current settings

In the Grail bucket management UI, or with the dtctl CLI:

```
dtctl get buckets
```
