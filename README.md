# Dynatrace Terraform examples

Reusable Terraform examples for configuring Dynatrace with
the [`dynatrace-oss/dynatrace`](https://registry.terraform.io/providers/dynatrace-oss/dynatrace/latest)
provider.

Everything here is a **template**, not a deployable configuration. Copy a
directory, point it at your tenant, fill in the variables. No tenant URL,
token, account ID, bucket name, or team name is hardcoded anywhere in this
repository.

## Contents

| Area | Description |
|---|---|
| [`openpipeline/`](openpipeline/) | OpenPipeline — resource naming across record types, the singleton routing hazard, and per-topic examples (currently pipelines, pipeline groups, and routing) |
| [`rum/`](rum/) | Real User Monitoring — configuring frontends, ordered detection rules, and downloading/uploading a frontend's configuration with the Dynatrace provider alone ([`frontends-classic`](rum/frontends-classic/)); plus an API variant that also creates frontends but **needs providers beyond `dynatrace-oss/dynatrace`** — `restapi`, `time`, `local`, `http` ([`frontends-gen3-api`](rum/frontends-gen3-api/)). See the [comparison](rum/README.md#two-directories--which-one-do-you-want) |

## Prerequisites

Terraform >= 1.5 (the examples use optional object attributes and variable
`validation` blocks; `rum/frontends-gen3-api/01-frontend` needs >= 1.9), and a Dynatrace platform environment with a **platform
token** or OAuth client.

The examples run unchanged on macOS, Linux, and Windows. The `terraform`
commands are identical everywhere; only the shell syntax for setting
environment variables and copying files differs, so every setup snippet in this
repo is given for bash/zsh, PowerShell, and Command Prompt. On Windows, Git
Bash and WSL both take the macOS/Linux syntax as-is.

### Install Terraform

**macOS** — Homebrew:

```sh
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

**Linux** — Debian/Ubuntu, from the HashiCorp apt repository:

```sh
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Linux** — RHEL, Fedora, Amazon Linux:

```sh
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install -y terraform
```

**Windows** — winget or Chocolatey, in an elevated shell:

```powershell
winget install --id HashiCorp.Terraform -e
# or
choco install terraform
```

**Any platform** — download the zip from
[developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install),
extract it, and put the binary on your `PATH`.

Confirm the install — same command on every platform:

```
terraform -version
```

### Dynatrace credentials

Credentials are always supplied through the environment, never committed, and
only last for the current shell session.

**macOS / Linux** (bash, zsh) — also Git Bash and WSL on Windows:

```sh
export DYNATRACE_ENV_URL="https://<env-id>.apps.dynatrace.com"
export DYNATRACE_PLATFORM_TOKEN="dt0s16.********"
```

**Windows** — PowerShell (and PowerShell 7 on macOS/Linux):

```powershell
$env:DYNATRACE_ENV_URL = "https://<env-id>.apps.dynatrace.com"
$env:DYNATRACE_PLATFORM_TOKEN = "dt0s16.********"
```

**Windows** — Command Prompt:

```bat
set DYNATRACE_ENV_URL=https://<env-id>.apps.dynatrace.com
set DYNATRACE_PLATFORM_TOKEN=dt0s16.********
```

Do not quote the values in Command Prompt — `set` would store the quotes as
part of the value.

Classic API tokens work but create ownerless, world-writable settings objects —
see each example's notes.

## Conventions

Every example in this repo follows these rules. Please keep them when adding
one.

1. **No organization-specific values.** Placeholders are generic
   (`checkout-api`, `payments`, `example-team`). Anything environment-specific
   is a variable with a sensible default or no default at all.
2. **Credentials come from the environment.** Provider credential variables
   default to `null` so the provider falls back to `DYNATRACE_*` env vars.
   Mark them `sensitive = true`. The one exception is
   [`rum/frontends-gen3-api`](rum/frontends-gen3-api/): it calls a platform REST
   API through the `restapi` provider, which has no environment fallback, so it
   takes required `TF_VAR_dt_env_url` and `TF_VAR_dt_platform_token` variables.
3. **Standard file layout** per stack: `versions.tf`, `providers.tf`,
   `variables.tf`, `locals.tf`, `outputs.tf`, and resource files named after
   what they contain.
4. **Every variable has a `description`.** Add `validation` blocks where a
   wrong value fails late or silently.
5. **Only `*.tfvars.example` is committed.** Real `*.tfvars` files are
   gitignored, as are state files.
6. **Each example directory has a `README.md`** covering what it creates, how
   to run it, and anything destructive to know first.
7. **`terraform fmt` and `terraform validate` must both pass** before
   committing.
8. **Pin the provider** with `version = "~> 1.105"` and record which provider
   version the schema was verified against.
9. **Setup steps are given for macOS/Linux, PowerShell, and Command Prompt**
   wherever the syntax differs, so an example is runnable on any platform.

### Lock files

`.terraform.lock.hcl` is gitignored here. That is deliberate for a template
repo — a committed lock file goes stale and forces `terraform init -upgrade` on
everyone who copies a directory. **In a real deployment, commit the lock file.**

A lock file records provider hashes per platform. If your team runs Terraform on
more than one OS (for example laptops on macOS and CI on Linux), record all of
them so nobody hits a checksum error:

```
terraform providers lock -platform=darwin_arm64 -platform=darwin_amd64 -platform=linux_amd64 -platform=windows_amd64
```

## Adding an example

Create the directory. Examples are laid out as
`<feature>/<topic>/<stack>` — for example
`openpipeline/pipeline-groups/01-minimal`:

```sh
# macOS / Linux
mkdir -p <feature>/<topic>/<stack>
```

```powershell
# Windows — PowerShell
New-Item -ItemType Directory -Force -Path <feature>\<topic>\<stack>
```

```bat
:: Windows — Command Prompt
mkdir <feature>\<topic>\<stack>
```

Verify resource schemas against the provider rather than against documentation
or memory, after `terraform init`:

```sh
# macOS / Linux, Git Bash, WSL, PowerShell 7
terraform providers schema -json > schema.json
```

```powershell
# Windows PowerShell 5.1 — `>` writes UTF-16, which breaks jq and most JSON parsers
terraform providers schema -json | Out-File -Encoding utf8 schema.json
```

Then check these pass — identical on every platform — and note the provider
version you verified against in the example's README:

```
terraform fmt -check -recursive
terraform validate
```

**Then apply it against a throwaway environment.** A schema check is not a
validity check: the provider schema accepts attribute values the API rejects,
so a config can pass `fmt`, `validate`, and `plan` and still fail at `apply`.
Confirm the apply succeeds, that a second `plan` reports no drift, and that
`terraform destroy` cleans up.
