# 03 — Download and upload a frontend's configuration

Uses the provider's built-in **export utility** to download a frontend's
configuration as Terraform, then applies that Terraform to the same or another
frontend to upload it. There is no stack to deploy here — the utility is part of
the `dynatrace-oss/dynatrace` provider binary — so this directory is a
walkthrough.

What it does well: it writes real, reviewable HCL, and with `-ref` it turns a
detection rule's `insert_after` into a reference to the rule above it, so the
rules come back **in the same order**.

What it does not do — verified against a live tenant, so plan around it:

- **It only exports resources the provider has a typed resource for.** Enablement
  (`dynatrace_web_app_enablement`) and detection rules
  (`dynatrace_application_detection_rule_v2`) are covered. Newer RUM schemas
  such as `builtin:rum.web.xhr-exclusion` have no typed resource, and
  `dynatrace_generic_setting` is **not** exported, so those settings are
  missing from the download. Re-add them with `extra_settings` in
  [`01-frontend-settings`](../01-frontend-settings/).
- **It exports the whole environment**, not one frontend: every frontend's
  rules, plus the environment-wide enablement object. Filter it (below).
- **It does not create the target frontend.** Create it first — see the
  [guide](../README.md#2-create-the-frontend-first).

The token needs `settings:objects:read` to export and `settings:objects:write`
to upload.

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

### 2. Find the utility

It is the provider binary Terraform already downloaded. Run `terraform init` in
any stack in this directory, then:

```sh
# macOS / Linux, Git Bash, WSL
BIN=$(find .terraform/providers -name 'terraform-provider-dynatrace_v*' -type f | head -1)
```

```powershell
# Windows — PowerShell
$bin = (Get-ChildItem -Recurse .terraform\providers -Filter 'terraform-provider-dynatrace_v*.exe' | Select-Object -First 1).FullName
```

```bat
:: Windows — Command Prompt
for /r .terraform\providers %f in (terraform-provider-dynatrace_v*.exe) do @set BIN=%f
```

### 3. Download

Find the settings object ID of the frontend's enablement, so the export is
limited to that one frontend. The frontend must have a `scope` equal to its
entity ID; find it by name first:

```
dtctl get settings --schema builtin:rum.frontend.name
dtctl get settings --schema builtin:rum.web.enablement
```

The enablement list shows each object's `objectId` and `scope`; take the one
whose scope is your frontend's `APPLICATION-…` ID. Then export, into a folder
you choose:

```sh
# macOS / Linux, Git Bash, WSL
export DYNATRACE_TARGET_FOLDER="$PWD/export"
"$BIN" -export -ref -flat -skip-terraform-init \
  "dynatrace_web_app_enablement=<enablement objectId>" \
  dynatrace_application_detection_rule_v2
```

```powershell
# Windows — PowerShell
$env:DYNATRACE_TARGET_FOLDER = "$PWD\export"
& $bin -export -ref -flat -skip-terraform-init `
  "dynatrace_web_app_enablement=<enablement objectId>" `
  dynatrace_application_detection_rule_v2
```

```bat
:: Windows — Command Prompt
set DYNATRACE_TARGET_FOLDER=%CD%\export
"%BIN%" -export -ref -flat -skip-terraform-init "dynatrace_web_app_enablement=<enablement objectId>" dynatrace_application_detection_rule_v2
```

What the flags do:

| Flag | Effect |
|---|---|
| `-ref` | Writes dependencies as references. Without it, each rule's `insert_after` is a literal settings object ID from the source environment — wrong anywhere else, and no ordering for Terraform to enforce. |
| `-flat` | One directory of `.tf` files instead of a module tree. Easier to edit and apply. |
| `-skip-terraform-init` | Don't run `terraform init` for you. |

Without the `=<objectId>` filter the export also writes `environment.web_app_enablement.tf`
and every other frontend's files; delete any you do not want to upload.
**Leave `environment.web_app_enablement.tf` out of an upload** unless you mean to
change the environment-wide default.

Rules cannot be filtered by frontend: delete the rule files whose
`application_id` is not yours. If you delete some, make sure the files that
remain still reference only each other.

### 4. Upload

To copy the configuration onto another frontend — or into another environment —
point the files at it. Replace the source frontend's entity ID everywhere:

```sh
# macOS / Linux, Git Bash, WSL
sed -i.bak "s/APPLICATION-<SOURCE>/APPLICATION-<TARGET>/g" export/*.tf && rm export/*.bak
```

```powershell
# Windows — PowerShell
Get-ChildItem export\*.tf | ForEach-Object {
  (Get-Content $_) -replace 'APPLICATION-<SOURCE>', 'APPLICATION-<TARGET>' | Set-Content $_
}
```

```bat
:: Windows — Command Prompt: use PowerShell above, or edit the files by hand
```

Look the target's entity ID up with
`dtctl get settings --schema builtin:rum.frontend.name`. Then, from the export
directory:

```
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

The plan should show only the enablement and rule resources, all `will be created`
or updated in place. If it shows anything for `environment`, stop and remove it.

Clean up with `terraform destroy`; the target frontend is not deleted.

## Rule placement

Rules are appended to the environment-wide list. The uploaded block keeps its
own internal order. Because the first exported rule has `insert_after = ""`,
check the result in the UI or with
`dtctl get settings --schema builtin:rum.web.app-detection` if relative order
against other frontends' rules matters to you.

Verified against `dynatrace-oss/dynatrace` v1.105.0 (export utility from the same
binary), Terraform 1.16: a customized frontend's enablement and four rules were
exported with `-ref -flat`, re-pointed at a second frontend, applied, planned
again with no changes, and the rules arrived in the original order.
