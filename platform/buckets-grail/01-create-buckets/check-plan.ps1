# Fails if a saved plan would delete a bucket or shorten a bucket's retention.
# Both can destroy data; a retention decrease is an in-place update that
# Terraform itself does not flag.
#
#   terraform plan -out=tf.plan
#   .\check-plan.ps1 tf.plan; if ($?) { terraform apply tf.plan }
param([string]$Plan = "tf.plan")

$planJson = terraform show -json $Plan | ConvertFrom-Json
if ($planJson.errored) {
  Write-Error "The plan errored, so it cannot be checked. Fix the plan error first."
  exit 2
}

$changes = $planJson.resource_changes |
  Where-Object { $_.type -eq "dynatrace_platform_bucket" }

$problems = foreach ($c in $changes) {
  if ($c.change.actions -contains "delete") {
    "$($c.address): would be DELETED ($($c.change.actions -join ','))"
  }
  elseif (($c.change.actions -contains "update") -and
          ($c.change.before.retention -gt $c.change.after.retention)) {
    "$($c.address): retention $($c.change.before.retention) -> $($c.change.after.retention) days deletes older data"
  }
}

if ($problems) {
  Write-Error ("UNSAFE plan:`n" + ($problems -join "`n"))
  exit 1
}
Write-Output "Plan is safe: no bucket is deleted and no retention is shortened."
