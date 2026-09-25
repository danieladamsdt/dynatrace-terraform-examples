# 01 — Minimal OpenPipeline group

The four objects in one file, with nothing abstracted away. Read
[`main.tf`](main.tf) top to bottom; it is commented as a walkthrough.

Creates: one base pipeline, one member pipeline, one pipeline group, and the
logs routing table.

```
export DYNATRACE_ENV_URL="https://<env-id>.apps.dynatrace.com"
export DYNATRACE_PLATFORM_TOKEN="dt0s16.********"

terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

> **Applying this replaces the environment's entire logs routing table.** Use a
> throwaway environment, or export the existing table first — see
> [the routing section of the guide](../README.md#2-the-routing-table-is-a-singleton--read-this-before-your-first-apply).

Clean up with `terraform destroy`.
