# RUM frontends with the `dynatrace-oss/dynatrace` provider

How to configure Dynatrace RUM frontends — enablement, per-frontend settings,
ordered detection rules, and download/upload of a frontend's configuration — using
**only** the `dynatrace-oss/dynatrace` provider.

One limit up front: **this provider cannot create a frontend** with a platform
token. [Creating the frontend first](#2-create-the-frontend-first) is a manual
step, and everything else is Terraform. A sibling directory,
[`../frontends-gen3-api`](../frontends-gen3-api/), creates frontends from
Terraform too, but only by adding other providers.

Everything here runs on macOS, Linux, and Windows. The `terraform` commands are
identical on all three; each stack's README gives environment-variable and
file-copy syntax for bash/zsh, PowerShell, and Command Prompt. See the
[root README](../../README.md#install-terraform) for installing Terraform.

| Stack | Does |
|---|---|
| [`01-frontend-settings`](01-frontend-settings/) | Enablement (including Grail storage) and any other per-frontend setting, for an existing frontend |
| [`02-detection-rules`](02-detection-rules/) | Detection rules whose order is guaranteed |
| [`03-export-import`](03-export-import/) | Download a frontend's configuration with the provider's export utility and upload it to another frontend |

The directory is called "classic" because the resources it uses
(`dynatrace_web_app_enablement`, `dynatrace_application_detection_rule_v2`) carry
the names of classic RUM applications. They configure the same frontends that
the latest RUM experience shows, and they are what the provider offers today.

---

## 1. What a frontend is

A frontend is the unit RUM data is grouped under. Every `user.events` and
`user.sessions` record carries a `frontend.name`, which is what you filter on in
DQL:

```
fetch user.events
| filter frontend.name == "checkout-web"
```

| Type | How data is attributed to it | Detection rules |
|---|---|---|
| Web, OneAgent injects the JavaScript (`WEB_AUTO_INJECTED`) | URL-based detection rules | yes |
| Web, you add the JavaScript snippet (`WEB_AGENTLESS`) | The frontend's ID inside the snippet | no |
| Android / iOS (`MOBILE`) | The frontend's ID in the SDK configuration | no |

## 2. Create the frontend first

The `dynatrace-oss/dynatrace` provider's only frontend-creating resources,
`dynatrace_web_application` and `dynatrace_mobile_application`, call the classic
Config API. That API rejects a platform token: with one, `terraform apply`
fails with `Authorization header contains unsupported authorization scheme
'Api-Token'`, and passing a platform token as the API token fails the same way.
They need a classic API token (`ReadConfig`, `WriteConfig`), which many tenants
cannot issue. They also cannot set `frontend.name`.

Settings cannot create a frontend either. The `applicationId` of a detection
rule must be an existing application, and `builtin:rum.frontend.name` rejects a
scope that does not exist.

So create the frontend one of these ways, then manage it with the stacks here.

**In the UI:** Experience Vitals → **Frontend** → pick the type → name it.

**With the Gen3 RUM API** — `POST /platform/rum/v1/frontends`, which needs a
platform token with `rum:frontends:write`. Put the body in `frontend.json`:

```json
{ "displayName": "Checkout Web", "frontendName": "checkout-web", "type": "WEB_AUTO_INJECTED" }
```

`type` is `WEB_AUTO_INJECTED`, `WEB_AGENTLESS`, `MOBILE`, or `CORDOVA`. `frontendName`
must be unique across web and mobile, can use only `A-Z a-z 0-9 - _ . ~`, and
**cannot be changed later**.

```sh
# macOS / Linux, Git Bash, WSL
curl -sS -X POST "$DYNATRACE_ENV_URL/platform/rum/v1/frontends" \
  -H "Authorization: Bearer $DYNATRACE_PLATFORM_TOKEN" \
  -H "Content-Type: application/json" -d @frontend.json
```

```powershell
# Windows — PowerShell
Invoke-RestMethod -Method Post -Uri "$env:DYNATRACE_ENV_URL/platform/rum/v1/frontends" `
  -Headers @{ Authorization = "Bearer $env:DYNATRACE_PLATFORM_TOKEN" } `
  -ContentType "application/json" -InFile frontend.json
```

```bat
:: Windows — Command Prompt (curl.exe ships with Windows 10 and later)
curl -sS -X POST "%DYNATRACE_ENV_URL%/platform/rum/v1/frontends" -H "Authorization: Bearer %DYNATRACE_PLATFORM_TOKEN%" -H "Content-Type: application/json" -d @frontend.json
```

The response carries the new `FRONTEND-…` ID. Delete a frontend with
`DELETE /platform/rum/v1/frontends/{id}` (`rum:frontends:delete`); it sometimes
answers `400 … no application with id … found`, and repeating the call then
succeeds. The API has no update and no GET.

**Wait about 30 seconds before applying anything.** A new frontend shows up in the
settings list straight away, but for the first few seconds writing its
enablement fails with `rum/enabledOnGrail: New Real User Monitoring Experience
can't be enabled`. That is a race, not a misconfiguration: the same apply succeeded
on a retry 30 seconds later, and re-running `terraform apply` is safe.

## 3. How the stacks find your frontend

A frontend has four names, and each API wants a different one.

| Identifier | Example | Used by |
|---|---|---|
| `frontend.name` | `checkout-web` | DQL, `user.events`, and **these stacks' `frontend_name` variable** |
| Display name | `Checkout Web` | The UI |
| Frontend ID | `FRONTEND-634BBBCA5843EFC3` | The Gen3 RUM API, Smartscape |
| Entity ID | `APPLICATION-3F37F2DB7A3FBBFA` (web), `MOBILE_APPLICATION-…` (mobile) | Detection rules, the provider's settings resources, the classic Settings API |

The entity ID cannot be derived from the frontend ID, but every frontend has a
`builtin:rum.frontend.name` settings object whose **scope is its entity ID**. The
stacks read those with `data "dynatrace_generic_settings"` and match on the name,
so you only ever supply `frontend_name`.

List the mapping yourself:

```
dtctl get settings --schema builtin:rum.frontend.name
```

Smartscape also knows both IDs (`smartscapeNodes FRONTEND | fields id, id_classic`),
but it keeps deleted frontends in its results for the query's timeframe, so
treat the settings list as the source of truth.

## 4. Token scopes

A platform token (or OAuth client) with `settings:objects:read` and
`settings:objects:write` runs every stack here. Creating or deleting a frontend
by API additionally needs `rum:frontends:write` / `rum:frontends:delete`.

## 5. Detection rules

Auto-injected frontends are matched by **detection rules**: a matcher and a
pattern against the page URL.

| Matcher family | Matchers |
|---|---|
| Entire URL | `URL_STARTS_WITH`, `URL_ENDS_WITH`, `URL_CONTAINS`, `URL_EQUALS` |
| Domain only | `DOMAIN_STARTS_WITH`, `DOMAIN_ENDS_WITH`, `DOMAIN_CONTAINS`, `DOMAIN_EQUALS`, `DOMAIN_MATCHES` |

- **One list for the whole environment** (`builtin:rum.web.app-detection`, up to
  1,000 rules). Every frontend's rules are interleaved in it; a rule's
  `applicationId` says which frontend it feeds.
- **First match wins**, top to bottom.
- **New rules go to the end** of that list, below every rule that already
  exists — including other frontends' rules.
- **`applicationId` is the entity ID**, not the `FRONTEND-…` ID.
- **Creation order is not controlled** when one resource creates several rules.
  [`02-detection-rules`](02-detection-rules/) explains what was tried and the
  pattern that works.

## 6. Other per-frontend settings

Each of these schemas holds objects scoped to a frontend's entity ID. Write any of
them with `extra_settings` in [`01-frontend-settings`](01-frontend-settings/).

| Area | Schemas |
|---|---|
| Names | `builtin:rum.frontend.name`, `builtin:rum.web.name`, `builtin:rum.mobile.name` |
| Enablement, cost and traffic control | `builtin:rum.web.enablement`, `builtin:rum.mobile.enablement` |
| JavaScript injection | `builtin:rum.web.automatic-injection`, `builtin:rum.web.custom-injection-rules`, `builtin:rum.web.injection.cookie`, `builtin:rum.web.manual-insertion`, `builtin:rum.web.rum-javascript-updates`, `builtin:rum.web.rum-cookies-upgrade` |
| Beacon | `builtin:rum.web.beacon-endpoint`, `builtin:rum.mobile.beacon-endpoint` |
| Capture | `builtin:rum.web.capture-properties`, `builtin:rum.web.capture-custom-properties`, `builtin:rum.mobile.capture-properties` |
| Exclusions | `builtin:rum.web.browser-exclusion`, `builtin:rum.web.ipaddress-exclusion`, `builtin:rum.web.xhr-exclusion` |
| Frontend–backend linking | `builtin:rum.web.frontend-backend-linking`, `builtin:rum.mobile.frontend-backend-linking` |
| Privacy | `builtin:rum.mobile.privacy`, `builtin:sessionreplay.web.privacy-preferences`, `builtin:sessionreplay.web.resource-capturing` |

```
dtctl get settings-schemas
dtctl get settings-schema builtin:rum.web.enablement
```

A new frontend already has objects for its name, enablement, and JavaScript
updates, holding defaults. Writing one **updates it in place** rather than failing on
a duplicate. Everything else has no object until you create one.

## 7. Gotchas

- **Applying right after creating a frontend can fail once.** See
  [creating the frontend first](#2-create-the-frontend-first); wait, then re-run.
- **The name schemas cannot be destroyed.** `builtin:rum.frontend.name`,
  `builtin:rum.web.name`, and `builtin:rum.mobile.name` are created with the
  frontend, and the API refuses to delete them (`Deletion of value(s) is not
  allowed`). A Terraform resource managing one can never be destroyed, so
  [`01-frontend-settings`](01-frontend-settings/) rejects them.
- **`frontend.name` cannot be changed**, and the display name is changed in the
  UI, not here.
- **Export misses newer schemas.** The export utility only covers resources the
  provider has a typed resource for; see [`03-export-import`](03-export-import/).
- **Don't write the same rules from two places.** Using
  [`02-detection-rules`](02-detection-rules/) and another configuration (or the
  UI) for one frontend creates duplicates.

## 8. Verified against

| Component | Version |
|---|---|
| `dynatrace-oss/dynatrace` | 1.105.0 |
| Terraform | 1.16 |
| Gen3 RUM API (`/platform/rum/v1`) | 1.3.0 |

Each stack was applied against a live tenant, planned again with no changes, and
destroyed. See each stack's README for the specific cases exercised.
