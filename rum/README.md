# Dynatrace Real User Monitoring (RUM)

Terraform examples for configuring Real User Monitoring on the latest
Dynatrace — web and mobile **frontends**, and the settings around them.

These examples target RUM on the latest Dynatrace (Grail, `user.events` and
`user.sessions`), not RUM Classic. Classic "applications" are the same
underlying entities, which is why some identifiers and resource names below
still say `application`.

## Topics

| Directory | Provider | Covers |
|---|---|---|
| [`frontends-classic/`](frontends-classic/) | `dynatrace-oss/dynatrace` only | Configuring an existing frontend: enablement and Grail storage, other per-frontend settings, ordered detection rules, and download/upload with the provider's export utility. **Start here.** |
| [`frontends-gen3-api/`](frontends-gen3-api/) | `dynatrace-oss/dynatrace` **plus** `restapi`, `http`, `time`, `local` | Creating frontends from Terraform through the Gen3 RUM API, which the provider has no resource for. Outside this repository's provider policy; use it only if you need creation in Terraform. |

The provider cannot create a frontend with a platform token, which is why the
two directories exist. [`frontends-classic`](frontends-classic/README.md#2-create-the-frontend-first)
explains the limit and how to create the frontend first.

Not covered yet — session replay, anomaly detection, and key user actions.
See [adding an example](../README.md#adding-an-example) in the root README.
