# Dynatrace Real User Monitoring (RUM)

Terraform examples for configuring Real User Monitoring on the latest
Dynatrace — web and mobile **frontends**, and the settings around them.

These examples target RUM on the latest Dynatrace (Grail, `user.events` and
`user.sessions`), not RUM Classic. Classic "applications" are the same
underlying entities, which is why some identifiers and resource names below
still say `application`.

## Topics

| Directory | Covers |
|---|---|
| [`frontends/`](frontends/) | Creating frontends (auto-injected, agentless, mobile), detection rules, and exporting/importing a frontend's full configuration. |

Not covered yet — session replay, anomaly detection, and key user actions.
See [adding an example](../README.md#adding-an-example) in the root README.
