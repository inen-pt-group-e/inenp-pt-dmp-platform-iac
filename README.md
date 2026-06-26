# inenp-pt-dmp-platform-iac

This repo provisions the cluster and platform foundations; from there **GitOps
(ArgoCD)** deploys everything else.

> Main documentation entry point: [`inenp-pt-dmp-platform-gitops`](https://github.com/inen-pt-group-e/inenp-pt-dmp-platform-gitops).

## Scope

After the IaC run, the platform exists and ArgoCD takes over.
Two documented secret exceptions exist (see [Manual exceptions](#manual-exceptions)).

What this repository provisions:

| File | Provisions |
| --- | --- |
| `apis.tf` | Enables the required Google Cloud APIs |
| `networking.tf` | VPC + subnet with secondary ranges (`platform-pods`, `platform-services`) |
| `gke.tf` | Zonal GKE cluster `platform`, autoscaling node pool (2–3× `e2-standard-2`), Workload Identity, **Calico network policy**, HTTP load balancing |
| `iam.tf` | Platform service accounts and IAM bindings |
| `workload-identity.tf` | Workload Identity bindings for ESO, ExternalDNS, cert-manager, Crossplane |
| `dns.tf` | Public Cloud DNS managed zone `mcce-project.xyz` |
| `secrets.tf` | Secret Manager containers (auto-generated + manual-upload) |
| `argocd.tf` | ArgoCD (Helm) + GitHub SSO + the app-of-apps bootstrap pointing at the GitOps repo |
| `pipeline.tf` | GitHub Actions Workload Identity Federation + the `terraform-pipeline` service account and roles |
| `monitoring.tf` | Cloud Monitoring dashboard, uptime check and alert policy |
| `backend.tf` | Terraform remote state (GCS) |

## Architecture (GitOps handoff)

```text
terraform apply  ->  GKE + VPC + IAM/Workload Identity + DNS + Secret Manager + ArgoCD
                     + app-of-apps root  ->  ArgoCD syncs the GitOps repo
                     ->  ingress-nginx, ESO, cert-manager, ExternalDNS, Crossplane,
                         CloudNativePG, and per-tenant SaaS instances
```

**Coordinates:** project `carbon-zone-496411-s6`, region `europe-west3`, zone
`europe-west3-a`, cluster `platform`, domain `mcce-project.xyz`.

## Prerequisites

- `gcloud` CLI and the `gke-gcloud-auth-plugin`
- Terraform/OpenTofu `>= 1.9`
- Permissions to create GKE, IAM, Cloud DNS, Secret Manager and Cloud Monitoring resources

## Bootstrap / apply flow

1. Authenticate and create the remote-state bucket (one-time):

   ```bash
   gcloud auth login
   ./scripts/bootstrap-backend.sh
   ```

2. **Changes are applied by CI/CD, not manually.** Open a pull request → `plan.yml` runs
   `terraform plan`; on merge to `main`, `apply.yml` runs `terraform apply` authenticated via
   Workload Identity Federation (no stored keys). For local validation only:

   ```bash
   terraform init
   terraform fmt -check
   terraform validate
   ```

3. After the first apply, upload the two manual secret values (see below).

## CI/CD pipeline

All pipelines authenticate to Google Cloud via **OIDC / Workload Identity Federation** as the
`terraform-pipeline` service account — no service-account keys are stored.

- `verify.yml` — `terraform fmt`/`validate`/lint on every PR
- `plan.yml` — `terraform plan` on every PR
- `apply.yml` — `terraform apply` on push to `main`

> Merging an IaC PR to `main` triggers the apply, which reconciles **all** of `main`'s state.
> The node pool uses **cluster autoscaling (2–3 nodes)** together with
> `lifecycle { ignore_changes = [node_count] }`, so GKE owns the live node count and a scale
> event (manual or by the autoscaler) is **not** reverted by the next apply.

## Secrets management

Secrets are either auto-generated or uploaded manually
as Secret Manager versions; the External Secrets Operator syncs them into the cluster.

- **Auto-generated:** `argocd-admin-password` (`random_password` → Secret Manager).
- **Manual exceptions** (cannot be auto-generated; uploaded once, never committed):
  - `argocd-github-oauth-client-secret` — the GitHub OAuth client secret for ArgoCD SSO.
  - `ghcr-pull-token` — a GitHub `read:packages` PAT, stored as a **dockerconfigjson**.

### Uploading the GHCR pull token

The tenant ExternalSecret maps the value verbatim into `.dockerconfigjson`, so the uploaded
value must be a complete dockerconfigjson document (not a raw PAT):

```bash
GH_USER="<github-username>"
GH_PAT="<pat-with-read:packages>"
AUTH=$(printf '%s:%s' "$GH_USER" "$GH_PAT" | base64 -w0)
printf '{"auths":{"ghcr.io":{"auth":"%s"}}}' "$AUTH" \
  | gcloud secrets versions add ghcr-pull-token --data-file=- --project carbon-zone-496411-s6
```

## Network policy

The cluster runs the **Calico** network policy add-on (`network_policy` +
`addons_config.network_policy_config`), so the per-tenant NetworkPolicies defined in the
GitOps repo are actually enforced (default-deny ingress + scoped allows).

## Monitoring

`monitoring.tf` defines a Cloud Monitoring dashboard **"Platform & Tenant Monitoring"**
(per-tenant CPU/memory/restarts, endpoint availability, cluster utilisation), an uptime check
and an alert policy. GKE already exports pod/container/node metrics to Cloud Monitoring, so no
self-hosted Prometheus/Grafana is required.

## Capacity & cost

The cluster is **zonal** and uses a **cluster-autoscaling** node pool of **2–3×
`e2-standard-2`** (cost-effective, highly available). The autoscaler keeps a **minimum of 2
nodes** for the platform stack plus roughly two tenants, and adds a **third node on demand**
when tenant load requires it; the platform becomes **CPU-bound before it is memory-bound**, so
CPU is the scaling trigger. When the extra load is gone the pool scales back to 2. The maximum
of 3 nodes caps cost while still allowing a live demo tenant to be provisioned. Capacity and
cost planning, including plan-vs-actual, is tracked in
[issue #1](https://github.com/inen-pt-group-e/inenp-pt-dmp-platform-iac/issues/1).

## Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `project_id` | `carbon-zone-496411-s6` | GCP project |
| `region` | `europe-west3` | GCP region |
| `zone` | `europe-west3-a` | GCP zone (zonal cluster) |
| `argocd_oauth_secret_writers` | `["user:r.matthias3@gmail.com"]` | Principals allowed to upload the ArgoCD OAuth secret version |
| `ghcr_pull_token_writers` | `["user:r.matthias3@gmail.com"]` | Principals allowed to upload the GHCR pull-token version |
| `monitoring_uptime_host` | `acme.mcce-project.xyz` | Host probed by the uptime check |
| `alert_notification_email` | `r.matthias3@gmail.com` | Recipient of platform alerts |

## Manual exceptions

The only deviations from a fully automated, click-free deployment are the two manual secret
uploads above (`argocd-github-oauth-client-secret`, `ghcr-pull-token`) — both values originate
outside the platform and must not be stored in Git. Terraform manages only their secret
containers and write permissions.

## Related repositories

| Repo | Purpose |
| --- | --- |
| [`inenp-pt-dmp-platform-gitops`](https://github.com/inen-pt-group-e/inenp-pt-dmp-platform-gitops) | ArgoCD app-of-apps; platform components + tenants (main docs entry point) |
| [`inenp-pt-dmp-backend`](https://github.com/inen-pt-group-e/inenp-pt-dmp-backend) | REST API container source (public) |
| [`inenp-pt-dmp-frontend`](https://github.com/inen-pt-group-e/inenp-pt-dmp-frontend) | SPA frontend container source (private) |

## GenAI Usage

- **Architecture & approach** — planning the IaC layout (GKE, networking, Workload Identity,
  ArgoCD bootstrap) and the no-click GitOps handoff.
- **File / code authoring** — assistance writing Terraform resources, IAM / Workload-Identity
  bindings and the CI/CD pipeline workflows.
- **Troubleshooting** — debugging terraform plan/apply, node pool autoscaling and Secret
  Manager / ESO issues.
- **Text creation** — providing generic text for issues and pull requests.

## Contributing

- Branch naming: `<type>/<short-description>`
- Conventional Commits; every commit/PR references its issue
- All changes land via squash-merged pull requests (no merge commits); CI must pass
