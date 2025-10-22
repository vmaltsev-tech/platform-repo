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

Authenticate against GCP (`gcloud auth login` or service-account key) and set the project `cnp-1760771836`.

## Deploying Infrastructure
```bash
cd infra/tf
terraform init
terraform apply
```
State is stored in bucket `tf-state-platform-vm` (prefix `gke-platform`). Default variable values live in `terraform.tfvars`. After apply:

```bash
gcloud container clusters get-credentials gke-platform \
  --region us-central1 \
  --project cnp-1760771836
```

## Bootstrapping GitOps
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

- `./scripts/check-gateway.sh app.wminor.xyz` – validates HTTPS entrypoint (uses Terraform output IP by default, expects HTTP 200).
- `./scripts/check-argocd.sh [app]` – waits until an Argo CD application is Healthy/Synced.

## Cleanup
Disable auto-sync in Argo CD if necessary, then run `terraform destroy` from `infra/tf`. Use `terraform force-unlock <id>` if a lock remains in the GCS backend.

## Further Details
See `docs/README.md` for expanded descriptions and operational notes.
