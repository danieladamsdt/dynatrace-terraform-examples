# 01 — Configure an existing frontend

Sets a frontend's enablement — including whether its data is stored in Grail,
where DQL reads it — and any other per-frontend settings object, for a frontend
that already exists.

This stack does **not** create the frontend. The `dynatrace-oss/dynatrace`
provider cannot do that with a platform token; see
[creating the frontend first](../README.md#2-create-the-frontend-first).

Creates: one `dynatrace_web_app_enablement` (or `dynatrace_mobile_app_enablement`
for a `MOBILE_APPLICATION-…` ID), and one `dynatrace_generic_setting` per entry
in `extra_settings`.

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

Edit `terraform.tfvars`. `frontend_name` is the `frontend.name` of a frontend
that already exists. The stack looks up its entity ID itself and fails the plan
with a clear message if no frontend has that name.

### 3. Apply

Identical on macOS, Linux, and Windows:

```
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

If the frontend was created less than a minute ago the first apply may fail with
`New Real User Monitoring Experience can't be enabled`. Wait 30 seconds and run
`terraform apply` again; it is safe to repeat.

Clean up with `terraform destroy`. That removes the settings this stack
created, resetting enablement to its defaults. It does not delete the frontend.

## What changes later

| Change | Result |
|---|---|
| Any variable | In place. |
| `frontend_name` | Settings are written to the other frontend and removed from the old one. |

## `extra_settings`

Any per-frontend schema can go here. List a schema's fields first:

```
dtctl get settings-schema builtin:rum.web.xhr-exclusion
```

Schemas that allow several objects — for example
`builtin:rum.web.xhr-exclusion` — take one entry per object. The variable
**rejects** the three name schemas (`builtin:rum.frontend.name`,
`builtin:rum.web.name`, `builtin:rum.mobile.name`): they are created with the
frontend and the API refuses to delete them
(`Deletion of value(s) is not allowed`), so a stack managing one could never
be destroyed.

## Notes

- Enablement already exists on every frontend with default values, so this
  stack **updates it in place** rather than creating it.
- Without `enabled_on_grail = true` a frontend's data is not queryable with
  `fetch user.events`.

Verified against `dynatrace-oss/dynatrace` v1.105.0, Terraform 1.16.
