# Dynatrace Real User Monitoring (RUM)

Terraform examples for configuring Real User Monitoring on the latest
Dynatrace — web and mobile **frontends**, and the settings around them.

These examples target RUM on the latest Dynatrace (Grail, `user.events` and
`user.sessions`), not RUM Classic. Classic "applications" are the same
underlying entities, which is why some identifiers and resource names below
still say `application`.

## Two directories — which one do you want?

They cover the same subject with different trade-offs. The deciding question is
whether **Terraform has to create the frontend itself**.

| | [`frontends-classic/`](frontends-classic/) | [`frontends-gen3-api/`](frontends-gen3-api/) |
|---|---|---|
| **Providers** | `dynatrace-oss/dynatrace` **only** | `dynatrace-oss/dynatrace` **plus** `Mastercard/restapi` (community), `hashicorp/time`, `hashicorp/local`, and `hashicorp/http` (export stack) |
| **Within this repo's provider policy** | Yes | **No** — an explicitly labeled exception |
| **Creates the frontend** | No. Create it first in the UI or with the Gen3 API; see [how](frontends-classic/README.md#2-create-the-frontend-first) | Yes, through `POST /platform/rum/v1/frontends` |
| **Configures an existing frontend** | Yes: enablement and Grail storage, any per-frontend setting | No — it only works on frontends it creates (the import stack applies a bundle to a new frontend) |
| **Detection rules** | Ordered, guaranteed (up to 5 per stack) | `01-frontend` creates them unordered; `03-import` keeps bundle order (up to 10). Use the classic stack when order matters |
| **Download / upload** | The provider's built-in export utility | Custom JSON bundle stacks |
| **Terraform version** | 1.5 or later | 1.9 or later for `01-frontend` |
| **Credentials** | `DYNATRACE_*` environment variables, like the rest of the repo | `TF_VAR_dt_env_url` and `TF_VAR_dt_platform_token`; the extra providers can't read `DYNATRACE_*` |
| **Maturity of what it calls** | Settings APIs | Gen3 RUM API, early-adopter |

**Start with `frontends-classic`.** Reach for `frontends-gen3-api` only if you
need Terraform to create frontends and accept the extra providers. The reason both
exist: the Dynatrace provider cannot create a frontend with a platform token, and
the Gen3 API call that can has no provider resource.

Not covered yet — session replay, anomaly detection, and key user actions.
See [adding an example](../README.md#adding-an-example) in the root README.
