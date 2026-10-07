# Platform

Dynatrace platform-level configuration with the
[`dynatrace-oss/dynatrace`](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest)
provider: the pieces every other feature sits on.

| Directory | Description |
|---|---|
| [`buckets-grail/`](buckets-grail/) | Creating Grail buckets and editing their retention and display name, **without ever deleting a bucket or its data** — plus adopting buckets that were created in the UI |

See the [root README](../README.md) for installing Terraform, setting
credentials, and the conventions every example follows.
