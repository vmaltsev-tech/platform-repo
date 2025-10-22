# Platform Infrastructure Overview

## Terraform Environment
- State backend: GCS bucket `tf-state-platform-vm`, prefix `gke-platform` (configured in `infra/tf/providers.tf`).
- Variables: defaults live in `terraform.tfvars`; additional overrides via CLI or env `TF_VAR_*`.
- Required tooling: Terraform ≥ 1.5, `gcloud` for fetching cluster credentials.

### Apply Workflow
1. Authenticate against GCP (`gcloud auth login` or service account) and select project `cnp-1760771836`.
2. From `infra/tf/` run `terraform init` and `terraform apply`.
3. After apply, retrieve kubeconfig: `gcloud container clusters get-credentials gke-platform --region us-central1 --project cnp-1760771836`.

### Key Terraform Resources
- `vpc.tf`: VPC, subnet with secondary ranges, private Google access.
- `nat.tf`: Cloud Router + NAT for private nodes.
- `gke.tf`: Private GKE cluster, node pool, Gateway API enabled, master authorized networks parameterized.
- `dns.tf` + `ip.tf`: Managed zone and static global IP that feeds the A record.
- `firewall.tf`, `iam.tf`: Control-plane firewall rule, node service account roles.

## GitOps Layout (Argo CD)
- Bootstrap manifests in `platform/argo/bootstrap`: AppProject `platform` and root Application `platform-root` (pulls apps from `platform/argo/apps`).
- Managed applications:
  - `platform-namespaces`: ensures namespaces `platform`, `dev`, `prod`.
  - `gateway`: deploys namespace `ingress`, Gateway, ManagedCertificate, stub backend, HTTPRoute.
- After applying bootstrap manifests (`kubectl apply -f platform/argo/bootstrap/`), sync `platform-root` via Argo CD UI or CLI (`argocd app sync platform-root`).

## Validation Scripts
- `scripts/check-gateway.sh <host> [ip]`: Uses `curl --resolve` to confirm HTTPS returns 200; pulls IP from Terraform output if not provided.
- `scripts/check-argocd.sh [app]`: Waits until the specified Argo application is Healthy/Synced.
- Remember to grant execute permission (`chmod +x scripts/check-*.sh`).

## Post-Deployment Checks
1. `./scripts/check-gateway.sh app.wminor.xyz` → expect HTTP 200 body from stub backend.
2. `./scripts/check-argocd.sh` → ensures `platform-root` is Healthy/Synced.
3. Optionally view Terraform outputs: `terraform output` (gateway IP, DNS zone, cluster name).

## Ops & Drift Handling
- Schedule periodic `terraform plan` runs; if a resource has been changed manually, either accept the drift or import/update the Terraform config.
- Use `terraform state list` to confirm state coverage before migrating backends or performing major changes.
- Within Argo CD, `argocd app diff` helps review differences before syncing.

## CI/CD Suggestions
- Add pipelines for `terraform fmt -check`, `terraform validate`, and `terraform plan`.
- Automate Argo CD sync triggers after successful Terraform apply, or rely on auto-sync with notifications for failures.

## Cleanup
- Disable automated sync for managed applications if tearing down.
- Run `terraform destroy` from `infra/tf/` to remove resources.
- Remove state lock in GCS if destroy interrupted (`terraform force-unlock <id>`).
