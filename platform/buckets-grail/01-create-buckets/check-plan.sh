#!/usr/bin/env bash
# Fails if a saved plan would delete a bucket or shorten a bucket's retention.
# Both can destroy data; a retention decrease is an in-place update that
# Terraform itself does not flag.
#
#   terraform plan -out=tf.plan
#   ./check-plan.sh tf.plan && terraform apply tf.plan
#
# Requires jq. Run it from the stack directory, after `terraform init`.
# Exits 1 for an unsafe plan and 2 if it cannot run, so `&&` never applies on
# a failed check.
set -euo pipefail

plan="${1:-tf.plan}"

command -v jq >/dev/null || { echo "check-plan.sh needs jq on PATH." >&2; exit 2; }
[ -f "$plan" ] || { echo "Plan file not found: $plan" >&2; exit 2; }

plan_json=$(terraform show -json "$plan")

if [ "$(jq -r '.errored // false' <<<"$plan_json")" = "true" ]; then
  echo "The plan errored, so it cannot be checked. Fix the plan error first." >&2
  exit 2
fi

problems=$(jq -r '
  .resource_changes[]?
  | select(.type == "dynatrace_platform_bucket")
  | if (.change.actions | index("delete")) then
      "\(.address): would be DELETED (\(.change.actions | join(",")))"
    elif ((.change.before.retention // 0) > (.change.after.retention // 0)
          and (.change.actions | index("update"))) then
      "\(.address): retention \(.change.before.retention) -> \(.change.after.retention) days deletes older data"
    else empty end' <<<"$plan_json")

if [ -n "$problems" ]; then
  echo "UNSAFE plan:" >&2
  echo "$problems" >&2
  exit 1
fi
echo "Plan is safe: no bucket is deleted and no retention is shortened."
