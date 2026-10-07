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
| `display_name` | Yes | None. Omitting it clears the label. |
| `name` | **No** — forces replacement | Deleting the bucket deletes its data |
| `table` | **No** — forces replacement | Deleting the bucket deletes its data |

The provider has no other mutable setting; Grail itself locks the name and table
after creation.

## The two guards

**1. `prevent_destroy = true` blocks every route to deleting a bucket.** Each
stack sets it on the bucket resource. Terraform then fails the *plan* — before
anything is sent to Dynatrace — for each of:

- changing `table` or the bucket name (a replacement is a destroy followed by a
  create)
- removing a bucket from the configuration
- `terraform destroy`

The error is `Instance cannot be destroyed`. All four were tested live.
`prevent_destroy` must be a literal in the `.tf` file; Terraform does not allow a
variable there, so removing a bucket on purpose means editing that line.

**2. A retention decrease needs a plan check.** Lowering retention is an
ordinary in-place update to Terraform: the plan reads `retention = 60 -> 35`
with `0 to destroy`, `prevent_destroy` does not fire, and the apply succeeds
without a prompt. Grail then deletes the older records, which can take days.
Each stack ships `check-plan.sh` (needs `jq`) and `check-plan.ps1`; both read the
saved plan and exit non-zero if a bucket would be deleted or its retention
shortened:

```sh
terraform plan -out=tf.plan
./check-plan.sh tf.plan && terraform apply tf.plan
```

```powershell
terraform plan -out=tf.plan
.\check-plan.ps1 tf.plan; if ($?) { terraform apply tf.plan }
```

`check-plan.sh` was tested on macOS. `check-plan.ps1` follows the same logic but
was **not** run, because PowerShell was not available where this was written.
Run it once against a plan that lowers retention before relying on it.

If you do mean to shorten retention, review the plan, accept that data older
than the new value will be deleted, and apply without the check.

## Pitfalls

- **A stale `terraform.tfvars` shortens retention.** Terraform applies the value
  in the file, whatever the bucket currently has. If someone raised retention in
  the UI and your file still says the old number, the next apply lowers it again.
  Run `terraform plan` and read it before every apply, and keep the file in
  version control so it is the source of truth.
- **Retention drops are not blocked by `prevent_destroy`.** See guard 2.
- **A bucket reports `status = "updating"` for a while after a change.** Wait
  for `active` before the next edit.
- **Deleting a bucket is asynchronous** and can take a long time on a large
  bucket. The `terraform destroy` flow below is only for test buckets.
- **Limits.** Retention is 1 to 3657 days. Bucket names are 3 to 100
  characters, start with a lowercase letter, and use only lowercase letters,
  digits, underscores, and hyphens. A tenant has 80 custom buckets by default.
- **Only custom buckets are manageable.** Many `default_*` buckets report
  `updatable: false` and cannot be edited. Do not import those.
- **The token needs the bucket-definition scopes.** Use a platform token with
  `storage:bucket-definitions:read` and `storage:bucket-definitions:write`. A
  classic API token cannot manage buckets. Without the scopes every call fails
  with `Required permissions not met`.

## Removing a test bucket

Throwaway buckets only — this deletes the data.

1. Delete the `prevent_destroy = true` line (or set it to `false`) in
   `buckets.tf` and run `terraform apply` so the change is recorded.
2. Run `terraform destroy`.
3. Restore the line.

To stop managing a bucket **without deleting it**, run
`terraform state rm 'dynatrace_platform_bucket.this["<bucket-name>"]'` and remove
it from the configuration. The bucket and its data stay in the tenant.

## Reading a bucket's current settings

In the Grail bucket management UI, or with
[dtctl](https://github.com/dynatrace-oss/dtctl):

```
dtctl get buckets
```
