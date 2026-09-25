# Dynatrace Terraform examples

Reusable, customer-agnostic Terraform examples for configuring Dynatrace with
the [`dynatrace-oss/dynatrace`](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest)
provider.

Everything here is a **template**, not a deployable configuration. Copy a
directory, point it at your tenant, fill in the variables. No tenant URL,
token, account ID, bucket name, team name, or customer name is hardcoded
anywhere in this repository.

## Contents

| Area | Description |
|---|---|
| [`dynatrace/openpipeline/pipeline-groups/`](dynatrace/openpipeline/pipeline-groups/) | OpenPipeline pipelines, pipeline groups, and routing — object model, stack layout, and the create/edit/delete lifecycle |

## Prerequisites

- Terraform >= 1.5 (the examples use optional object attributes and variable
  `validation` blocks). Install on macOS with:
  ```
  brew install hashicorp/tap/terraform
  ```
- A Dynatrace platform environment and a **platform token** or OAuth client.
  Classic API tokens work but create ownerless, world-writable settings objects
  — see each example's notes.

Credentials are always supplied through the environment, never committed:

```
export DYNATRACE_ENV_URL="https://<env-id>.apps.dynatrace.com"
export DYNATRACE_PLATFORM_TOKEN="dt0s16.********"
```

## Conventions

Every example in this repo follows these rules. Please keep them when adding
one.

1. **No customer-identifying values.** Placeholders are generic
   (`checkout-api`, `payments`, `example-team`). Anything environment-specific
   is a variable with a sensible default or no default at all.
2. **Credentials come from the environment.** Provider credential variables
   default to `null` so the provider falls back to `DYNATRACE_*` env vars.
   Mark them `sensitive = true`.
3. **Standard file layout** per stack: `versions.tf`, `providers.tf`,
   `variables.tf`, `locals.tf`, `outputs.tf`, and resource files named after
   what they contain.
4. **Every variable has a `description`.** Add `validation` blocks where a
   wrong value fails late or silently.
5. **Only `*.tfvars.example` is committed.** Real `*.tfvars` files are
   gitignored, as are state files.
6. **Each example directory has a `README.md`** covering what it creates, how
   to run it, and anything destructive to know first.
7. **`terraform fmt` and `terraform validate` must both pass** before
   committing.
8. **Pin the provider** with `version = "~> 1.105"` and record which provider
   version the schema was verified against.

### Lock files

`.terraform.lock.hcl` is gitignored here. That is deliberate for a template
repo — a committed lock file goes stale and forces `terraform init -upgrade` on
everyone who copies a directory. **In a real deployment, commit the lock file.**

## Adding an example

```
mkdir -p <product-area>/<feature>/<stack>
```

Verify resource schemas against the provider rather than against documentation
or memory:

```
terraform providers schema -json > schema.json    # after terraform init
```

Then check `terraform fmt -check -recursive` and `terraform validate` pass, and
note the provider version you verified against in the example's README.
