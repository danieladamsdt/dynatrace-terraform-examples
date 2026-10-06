# 03 — Export a frontend's configuration

Downloads the full configuration of an existing frontend into a bundle of JSON
files. [`04-import`](../04-import/) uploads a bundle to create the same
frontend again — in another environment, or under a new name.

Creates: no Dynatrace objects. It only reads settings and writes files to
`output_dir`.

The bundle:

```
bundle/
  frontend.json                           frontend.name, display name, type
  detection-rules.json                    this frontend's rules, in precedence order
  settings/
    builtin_rum.web.enablement.json       one file per schema that has
    builtin_rum.web.xhr-exclusion.json    non-default settings
    …
```

Only settings that differ from the defaults exist as objects, so a frontend
nobody has customized exports little more than its name. That is expected.

The token needs `settings:objects:read`.

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

### 2. Run it

```
terraform init
terraform apply -var="frontend_name=<frontend.name>" -var="application_type=auto_injected"
```

`application_type` is `auto_injected`, `agentless`, or `mobile`. Web versus
mobile is detected from the entity ID, but auto-injected versus agentless is
not exposed by any API, so say which it is.

Commit the bundle to Git if you want a reviewable record of the frontend's
configuration. It contains settings values only — no tokens.

### 3. Delete the state

The HTTP data sources record their request headers, including your token, in
state. Remove it once the export finishes:

```sh
# macOS / Linux, Git Bash, WSL
rm terraform.tfstate*
```

```powershell
# Windows — PowerShell
Remove-Item terraform.tfstate*
```

```bat
:: Windows — Command Prompt
del terraform.tfstate*
```

## What is and isn't exported

Exported: every per-frontend schema that can hold an object —
`frontend.name`, the web and mobile name, enablement, injection, beacon, cookie,
privacy, capture-property, and exclusion schemas, plus session replay privacy
and resource capture (the full list is `frontend_schemas` in
[`main.tf`](main.tf)) — and this frontend's detection rules.

Not exported: environment-wide settings (host headers, IP determination,
overload prevention), detection rules that belong to other frontends, and the
data the frontend has collected.

Verified against `hashicorp/http` v3.6.2 and `hashicorp/local` v2.9.1.
