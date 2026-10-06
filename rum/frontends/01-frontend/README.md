# 01 — Create a frontend

Creates one frontend from a display name, a `frontend.name`, and an
application type — `auto_injected`, `agentless`, or `mobile` — and optionally
its detection rules.

Creates: the frontend (via `POST /platform/rum/v1/frontends`), and for
auto-injected frontends, one detection rule per entry in `detection_rules`.

| `application_type` | Gen3 API `type` | Detection rules |
|---|---|---|
| `auto_injected` | `WEB_AUTO_INJECTED` | yes |
| `agentless` | `WEB_AGENTLESS` | no — matched by the application ID in your snippet |
| `mobile` | `MOBILE` | no — matched by the application ID in the SDK config |

The Gen3 API also has a `CORDOVA` type, which creates a paired web and mobile
frontend. It is not wired up here; add it to the `frontend_type` map in
[`main.tf`](main.tf) if you need it.

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

Edit `terraform.tfvars`. `frontend_name` must be unique across web and mobile
frontends in the environment, and may contain only `A-Z a-z 0-9 - _ . ~`.

### 3. Apply

Identical on macOS, Linux, and Windows:

```
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

The apply takes about a minute longer than you might expect. After the create
call, Terraform waits `settle_duration` (default 60 seconds) because the
frontend's entity takes up to ~40 seconds to appear, and the entity ID that
detection rules need cannot be looked up before then.

Clean up with `terraform destroy`. That deletes the frontend and everything
configured on it. Its collected data is not affected.

## What changes later

| Change | Result |
|---|---|
| `detection_rules` | In place — rules are added, updated, and removed. |
| `display_name` | **Ignored.** The API cannot rename; change it in the UI. |
| `frontend_name` or `application_type` | **Replaces the frontend** — a new ID, and all settings on the old one are lost. The plan shows `restapi_object.frontend must be replaced`. |

## Rule order

Rules created in one apply land in a random order, and new rules go to the
**end** of the environment-wide rule list, below every rule that already
exists. If two of your rules can match the same URL, use
[`02-ordered-detection-rules`](../02-ordered-detection-rules/) instead.

## Notes

- `data.http.entity` records its request header — your token — in state.
  State is gitignored; treat it as a secret.
- Refresh reads the frontend's `frontend.name` settings object, because the
  API has no GET. If you delete the frontend in the UI, the next plan sees the
  404 and proposes to recreate it. A plan run within ~40 seconds of creation
  would see the same 404, so don't chain a second plan onto an apply.

Verified against `dynatrace-oss/dynatrace` v1.105.0, `Mastercard/restapi`
v2.0.1, `hashicorp/http` v3.6.2, `hashicorp/time` v0.14.2, Terraform 1.16.
