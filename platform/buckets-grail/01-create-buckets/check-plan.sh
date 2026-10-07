#!/usr/bin/env bash
# Fails if a saved plan would delete a bucket or shorten a bucket's retention.
# Both can destroy data; a retention decrease is an in-place update that
# Terraform itself does not flag.
#
#   terraform plan -out=tf.plan
#   ./check-plan.sh tf.plan && terraform apply tf.plan
#
# Requires jq.
set -euo pipefail

plan="${1:-tf.plan}"

problems=$(terraform show -json "$plan" | jq -r '
  .resource_changes[]?
  | select(.type == "dynatrace_platform_bucket")
  | if (.change.actions | index("delete")) then
      "\(.address): would be DELETED (\(.change.actions | join(",")))"
    elif ((.change.before.retention // 0) > (.change.after.retention // 0)
          and (.change.actions | index("update"))) then
      "\(.address): retention \(.change.before.retention) -> \(.change.after.retention) days deletes older data"
    else empty end')

if [ -n "$problems" ]; then
  echo "UNSAFE plan:" >&2
  echo "$problems" >&2
  exit 1
fi
echo "Plan is safe: no bucket is deleted and no retention is shortened."
