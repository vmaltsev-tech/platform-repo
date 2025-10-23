# Platform Infrastructure Monorepo

This repository contains Terraform code, Kubernetes manifests, and GitOps configuration for the platform environment running on Google Cloud.

## Structure
- `infra/tf/` – Terraform configuration provisioning VPC, private GKE cluster (Gateway API enabled), NAT, DNS, static IP, IAM, firewall rules.
- `infra/apps/` – Kubernetes manifests for the ingress stack (Gateway, HTTPRoute, ManagedCertificate, stub backend) and shared namespaces.
- `platform/argo/` – Argo CD bootstrap and applications (AppProject, root Application, gateway and namespaces apps).
- `scripts/` – Helper scripts for post-deploy validation.
- `docs/` – Additional documentation (`docs/README.md`) and evidence placeholder.

## Prerequisites
- Terraform ≥ 1.5
- Google Cloud SDK (`gcloud`)
- kubectl
- Argo CD CLI (optional but recommended)

Authenticate against GCP (`gcloud auth login` or service-account key) and set your working project (e.g. `gcloud config set project <your-gcp-project-id>`).

## Deploying Infrastructure
Create a working `terraform.tfvars` based on the example and adjust values for your project:
```bash
cp infra/tf/terraform.tfvars.example infra/tf/terraform.tfvars
# edit infra/tf/terraform.tfvars (project_id, domain_name, host, master_authorized_networks, etc.)
```

```bash
cd infra/tf
terraform init
terraform apply
```
State is stored in bucket `tf-state-platform-vm` (prefix `gke-platform`). Default variable values live in `terraform.tfvars`. After apply:

```bash
gcloud container clusters get-credentials gke-platform \
  --region us-central1 \
  --project <your-gcp-project-id>
```

Sync Kubernetes manifests with the configured host (runs off Terraform output if no argument is supplied):
```bash
./scripts/sync-gateway-host.sh
```

## Bootstrapping GitOps
If you use a different Git remote, align the Argo manifests before applying:
```bash
./scripts/update-argocd-repo.sh https://github.com/your-org/platform-repo.git
# or omit the argument to reuse the current git remote
```

1. Ensure Argo CD is installed in the cluster (e.g. namespace `argocd`).
2. Apply bootstrap manifests:
   ```bash
   kubectl apply -f platform/argo/bootstrap/
   ```
3. Sync the root application:
   ```bash
   argocd app sync platform-root
   ```
   (or trigger sync via the Argo CD UI).

The root app pulls child applications:
- `platform-namespaces` – creates namespaces `platform`, `dev`, `prod`.
- `gateway` – manages ingress namespace, Gateway, ManagedCertificate, stub backend, HTTPRoute.

## Validation
Make helper scripts executable once:
```bash
chmod +x scripts/check-*.sh
```

- `./scripts/check-gateway.sh` – validates HTTPS entrypoint (defaults to Terraform outputs for host/IP, expects HTTP 200).
- `./scripts/check-argocd.sh [app]` – waits until an Argo CD application is Healthy/Synced.

## Cleanup
Disable auto-sync in Argo CD if necessary, then run `terraform destroy` from `infra/tf`. Use `terraform force-unlock <id>` if a lock remains in the GCS backend.

## Drift & Updates
- Run `terraform plan` regularly to detect infrastructure drift; if resources exist but are missing from state, recover them with `terraform import`.
- Use `argocd app diff <app>` to compare Git vs cluster state when investigating GitOps sync issues.
- For upgrades (e.g., new cluster versions), update variables or resource arguments, review the plan, and apply during a maintenance window.

## Troubleshooting
- **State lock stuck:** `terraform force-unlock <lock-id>` and relaunch the command.
- **Gateway CRDs missing:** ensure `terraform apply` rolled out the `gateway_api_config` change (`kubectl get crd | grep gateway`).
- **Managed certificate pending:** confirm the DNS A record resolves to the static IP from `terraform output gateway_ip`.
- **ArgoCD sync loops:** inspect controller logs (`kubectl logs -n argocd deploy/argocd-application-controller`) and pause auto-sync if manual fixes are required.

## Secrets & Access
- Use Application Default Credentials (`gcloud auth application-default login`) or a service-account key stored in a secure secret manager—never commit credentials.
- Workload Identity is enabled; bind Kubernetes service accounts to Google service accounts through IAM instead of distributing static keys.

## CI/CD Recommendations
- Add CI checks for `terraform fmt -check`, `terraform validate`, and `terraform plan`.
- Publish plan outputs in PRs for review prior to apply.
- Allow Argo CD to pull from this repository (deploy keys or robot Git user) and rely on auto-sync or pipeline-triggered syncs.

## Further Details
See `docs/README.md` for expanded descriptions and operational notes.
