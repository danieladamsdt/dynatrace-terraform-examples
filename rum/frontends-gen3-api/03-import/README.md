# 03 — Import a frontend's configuration

> **Uses providers beyond `dynatrace-oss/dynatrace`:** `Mastercard/restapi`, `hashicorp/time`, and `hashicorp/local`. This is the API variant,
> outside the repository's provider policy; see
> [the comparison](../../README.md#two-directories--which-one-do-you-want).

Creates a frontend from a bundle written by [`02-export`](../02-export/): the
frontend itself, every settings object in the bundle, and its detection rules,
in order.

Creates: one frontend (via `POST /platform/rum/v1/frontends`), one
`dynatrace_generic_setting` per object in `settings/`, and up to 10
detection rules.

Use it to copy a frontend to another environment, to stamp out a frontend from
a reviewed template, or to rebuild one that was deleted.

The token needs `rum:frontends:write`, `rum:frontends:delete`,
`settings:objects:read`, and `settings:objects:write`.

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

`bundle_dir` points at the directory `02-export` wrote. `frontend_name` and
`display_name` are optional overrides. **`frontend.name` is unique per
environment**, so importing into the environment you exported from requires a
new `frontend_name`; importing into a different environment can keep the
original.

### 3. Apply

```
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

Expect about a minute of waiting after the frontend is created — see
[the guide](../README.md#4-creating-a-frontend-takes-about-a-minute).

## What is and isn't replayed

- `builtin:rum.frontend.name`, `builtin:rum.web.name`, and
  `builtin:rum.mobile.name` are **not** replayed. The create call sets the
  frontend name and display name from `frontend.json` and the overrides.
- Every other schema file is applied to the new frontend. Most of them already
  exist with default values on a new frontend, so they are updated in place.
- Detection rules are created in bundle order, starting after
  `insert_rules_after` if you set it, otherwise at the end of the
  environment-wide list. Rules in the bundle beyond the 10 slots in
  [`rules.tf`](rules.tf) are not imported; a `check` block warns when that
  happens.
- Only `auto_injected` frontends have rules; the bundle's rules file is
  ignored for the other types.

## Tearing down

`terraform destroy` removes the frontend, its settings objects, and its rules,
and does not leave the frontend half-deleted. The one thing to avoid: do **not**
add the name schemas (`builtin:rum.web.name` and friends) to a
`dynatrace_generic_setting` of your own. They are created with the frontend and
the API refuses to delete them (`Deletion of value(s) is not allowed`), so
destroying a resource that manages one fails until you `terraform state rm` it.
That is why this stack skips them.

## Caveats

- **Multi-object settings are not order-preserving.** `builtin:rum.web.xhr-exclusion`
  and `builtin:rum.web.custom-injection-rules` hold several objects each. They
  are recreated with the same values but may be listed in a different order.
  Those schemas are unordered sets.

Verified for auto-injected web frontends only; agentless and mobile bundles have not been
imported. Verified against `dynatrace-oss/dynatrace` v1.105.0, `Mastercard/restapi`
v2.0.1, `hashicorp/time` v0.14.2, Terraform 1.16: a
bundle exported from a customized frontend (changed enablement, two XHR
exclusions, three detection rules) was imported under a new name, the settings
and rules matched, a second plan reported no changes, and `terraform destroy`
removed everything.
