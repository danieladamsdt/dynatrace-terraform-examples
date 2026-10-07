# RUM frontends in Terraform — Gen3 API variant

> **This variant uses providers beyond `dynatrace-oss/dynatrace`.** It adds
> `Mastercard/restapi` (a community provider) to call the Gen3 RUM API, plus
> `hashicorp/time` and `hashicorp/local` (and `hashicorp/http` in the export stack). That is outside this
> repository's provider policy, and the Gen3 RUM API is early-adopter maturity.
> Use it only if you need Terraform to **create** frontends. To configure
> frontends that already exist, use
> [`../frontends-classic`](../frontends-classic/) — it needs nothing but the
> Dynatrace provider. See [the side-by-side comparison](../README.md#two-directories--which-one-do-you-want).

How to create and manage Dynatrace RUM frontends with Terraform: what a
frontend is, which identifiers and APIs are involved, how detection rules work,
and how to download and upload a frontend's full configuration.

Everything here runs on macOS, Linux, and Windows. The `terraform` commands are
identical on all three; each stack's README gives environment-variable and
file-copy syntax for bash/zsh, PowerShell, and Command Prompt. See the
[root README](../../README.md#install-terraform) for installing Terraform.

| Stack | Does |
|---|---|
| [`01-frontend`](01-frontend/) | Create a frontend from a display name, `frontend.name`, and application type; optionally add detection rules |
| [`frontends-classic/02-detection-rules`](../frontends-classic/02-detection-rules/) | Detection rules whose order is guaranteed |
| [`02-export`](02-export/) | Download a frontend's full configuration to a JSON bundle |
| [`03-import`](03-import/) | Upload a bundle to create the same frontend again |

---

## 1. What a frontend is

A frontend is the unit RUM data is grouped under. Every `user.events` and
`user.sessions` record carries a `frontend.name`, and that is what you filter
on in DQL:

```
fetch user.events
| filter frontend.name == "checkout-web"
```

| Type | `application_type` here | Gen3 API `type` | How data is attributed to it |
|---|---|---|---|
| Web, OneAgent injects the JavaScript | `auto_injected` | `WEB_AUTO_INJECTED` | **Detection rules** — URL patterns evaluated by OneAgent |
| Web, you add the JavaScript snippet | `agentless` | `WEB_AGENTLESS` | The frontend's ID inside the snippet |
| Android / iOS | `mobile` | `MOBILE` | The frontend's ID in the SDK configuration |
| Hybrid mobile (Cordova) | not wired up | `CORDOVA` | Creates a paired web and mobile frontend |

## 2. One frontend, four identifiers

This is the part that trips people up. A frontend has four names, and each API
wants a different one.

| Identifier | Example | Where it comes from | Used by |
|---|---|---|---|
| `frontend.name` | `checkout-web` | You choose it. Unique across web and mobile. **Cannot be changed.** | DQL filters, `user.events` |
| Display name | `Checkout Web` | You choose it. Free text. | The UI |
| Frontend ID | `FRONTEND-634BBBCA5843EFC3` | Returned by `POST /platform/rum/v1/frontends` | The Gen3 RUM API, Smartscape, the platform Settings API |
| Entity ID | `APPLICATION-3F37F2DB7A3FBBFA` (web) or `MOBILE_APPLICATION-…` | Assigned by Dynatrace; **not derivable** from the frontend ID | Detection rules, the `dynatrace` provider's settings resources, the classic Settings API |

The two IDs are the same frontend seen through two generations of the product.
Smartscape exposes the link as `id_classic`:

```
smartscapeNodes FRONTEND
| filter frontend.name == "checkout-web"
| fields id, id_classic
```

Terraform can't run DQL, so these stacks resolve the entity ID another way: every
frontend has a `builtin:rum.frontend.name` settings object whose **scope is its
entity ID**. They read those with `data "dynatrace_generic_settings"` and match
on the unique `frontend.name`. That stays inside the `dynatrace` provider and
does not put your token in state.

You can list the same mapping yourself:

```
dtctl get settings --schema builtin:rum.frontend.name
```

Smartscape keeps deleted frontends in its results for the query's timeframe, so
treat the settings list as the source of truth for what exists.

## 3. Why there is a `restapi` provider here

The Gen3 way to create a frontend is `POST /platform/rum/v1/frontends`
(`rum:frontends:write`; early-adopter maturity as of this writing):

```json
{ "displayName": "Checkout Web", "frontendName": "checkout-web", "type": "WEB_AUTO_INJECTED" }
```

It returns the new `FRONTEND-…` ID. The only other operation on frontends is
`DELETE /platform/rum/v1/frontends/{id}`. There is no GET and no update.

The `dynatrace-oss/dynatrace` provider (v1.105.0) has no resource for this
API. Its `dynatrace_web_application` and `dynatrace_mobile_application`
resources use the **classic Config API**, which rejects a platform token
("no access token provided"), requires a classic API token, and cannot set
`frontend.name`. So these stacks call the Gen3 API with the
[`Mastercard/restapi`](https://registry.terraform.io/providers/Mastercard/restapi/latest)
provider, and use the `dynatrace` provider for everything that *is* a settings
object — detection rules and the per-frontend settings.

Because the API has no GET, `restapi_object` refreshes by reading the
frontend's `builtin:rum.frontend.name` settings object, and ignores the
response. That read cannot tell that a frontend was deleted out of band (it
returns an empty `200`, not a 404), so such drift is **not** detected; see
[`01-frontend`](01-frontend/README.md#things-that-can-go-wrong) for the recovery
command. When Dynatrace ships a native resource, replace `restapi_object.frontend`
with it and keep the rest.

### Token scopes

A platform token (or OAuth client) with:

| Scope | For |
|---|---|
| `rum:frontends:write` | Create |
| `rum:frontends:delete` | Destroy |
| `settings:objects:read`, `settings:objects:write` | Detection rules and per-frontend settings |

## 4. Creating a frontend takes about a minute

After the create call, the frontend's entity takes up to ~40 seconds to
appear. Until it does, settings reads and writes against it return
`404 … Smartscape scope 'FRONTEND-…' not found`, and the entity ID cannot be
looked up. The stacks insert a `time_sleep` (`settle_duration`, default 60
seconds) between the create and everything that depends on the entity. If you
see that 404 on a slow tenant, raise it.

The same 404 is why a plan run immediately after an apply may propose to
recreate the frontend. It is the entity not having appeared yet, not drift.

## 5. Detection rules

Auto-injected frontends are matched by **detection rules**: a matcher and a
pattern against the page URL.

| Matcher family | Matchers |
|---|---|
| Entire URL | `URL_STARTS_WITH`, `URL_ENDS_WITH`, `URL_CONTAINS`, `URL_EQUALS` |
| Domain only | `DOMAIN_STARTS_WITH`, `DOMAIN_ENDS_WITH`, `DOMAIN_CONTAINS`, `DOMAIN_EQUALS`, `DOMAIN_MATCHES` |

Things to know:

- **One list for the whole environment** (`builtin:rum.web.app-detection`,
  scope `environment`, up to 1,000 rules). Every frontend's rules are
  interleaved in it. A rule's `applicationId` says which frontend it feeds.
- **First match wins.** OneAgent evaluates rules top to bottom.
- **New rules go to the end** of that list — below every existing rule,
  including other frontends'. An existing broad rule can therefore shadow a new
  specific one.
- **`applicationId` is the entity ID**, not the `FRONTEND-…` ID.
- **Creation order is not controlled** when one resource creates several rules.
  See [`frontends-classic/02-detection-rules`](../frontends-classic/02-detection-rules/) for what was
  tried and the pattern that works.
- Agentless and mobile frontends don't use detection rules.

## 6. What else is configurable on a frontend

Each of these is a settings object whose scope is the frontend's entity ID.
Manage any of them with a `dynatrace_generic_setting` (`schema`, `scope`,
`value = jsonencode(…)`) — [`03-import`](03-import/) does exactly that for a
whole bundle.

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

List the schemas your tenant has, and read one:

```
dtctl get settings-schemas
dtctl get settings-schema builtin:rum.web.enablement
```

A newly created frontend already has objects for `frontend.name`, the web name,
enablement, and JavaScript updates, holding default values. Writing one with
`dynatrace_generic_setting` **updates it in place** rather than failing on a
duplicate. Everything else has no object until you create one.

## 7. Downloading and uploading a configuration

[`02-export`](02-export/) reads every per-frontend settings object and this
frontend's detection rules and writes them to a bundle of JSON files.
[`03-import`](03-import/) creates a frontend from a bundle: the frontend first,
then each settings object, then the rules in order.

It is a snapshot-and-replay, not a sync: each import creates a new frontend, and
Terraform only tracks what that import created.

## 8. Gotchas

- **`frontend.name` cannot change.** The API enforces it; Terraform replaces the
  frontend if you edit it, which discards the frontend's settings.
- **The display name is not updated by Terraform.** The create call sets it;
  after that, rename in the UI or through `builtin:rum.web.name`.
- **`02-export` puts your token in state.** It reads settings with
  `hashicorp/http`, which records request headers, so the `Authorization` header is
  stored. State is gitignored; don't share it, and delete it after exporting.
- **Credentials are `TF_VAR_*` here**, not `DYNATRACE_*` like the other
  examples, because the `restapi` provider has no environment fallback and
  both providers must agree on tenant and token.

## 9. Verified against

| Component | Version |
|---|---|
| `dynatrace-oss/dynatrace` | 1.105.0 |
| `Mastercard/restapi` | 2.0.1 |
| `hashicorp/http` (`02-export` only) | 3.6.2 |
| `hashicorp/time` | 0.14.2 |
| `hashicorp/local` | 2.9.1 |
| Terraform | 1.16 (`01-frontend` needs 1.9 or later; the others validate on 1.5) |
| Gen3 RUM API (`/platform/rum/v1`) | 1.3.0 |

Create, a clean second plan, replace-on-rename, and destroy were applied against a
live tenant for all three application types. The export and import round trip was
exercised for an auto-injected frontend only; agentless and mobile bundles have not
been imported. See each stack's README for what else was exercised.
