# IBS GitOps Platform

A production-grade GitOps platform running a Node.js application on AWS EKS, using ArgoCD for continuous delivery, Argo Rollouts for canary deployments, and the External Secrets Operator to sync AWS Secrets Manager credentials into Kubernetes.

---

## Table of Contents

- [Repository Architecture](#repository-architecture)
- [Project Overview & Data Flow](#project-overview--data-flow)
- [GitHub Workflows](#github-workflows)

---

## Repository Architecture

```
ibs-gitops-platform/
├── application/                    # Node.js application source
│   ├── app.js                      # Express app (visit counter, DB health, Prometheus metrics)
│   └── Dockerfile
│
├── helm/
│   └── charts/nodeapp/             # Helm chart for the application
│       ├── Chart.yaml
│       ├── values.yaml             # Default values
│       └── templates/
│           ├── node-deployment.yaml      # Argo Rollout (canary strategy)
│           ├── nginx-deployment.yaml     # Nginx reverse proxy
│           ├── ingress.yaml              # AWS ALB ingress
│           ├── hpa.yaml                  # Horizontal Pod Autoscaler
│           └── analysis-template.yaml   # Canary analysis template
│
├── gitops/
│   └── argocd-applications/
│       ├── applicationset.yaml           # ArgoCD ApplicationSet (multi-env generator)
│       ├── argocd-ingress.yml            # ArgoCD UI ingress (ALB)
│       ├── production/
│       │   └── values.yaml              # Production overrides (image tag, RDS secret, Redis)
│       ├── development/
│       │   └── values.yaml              # Development overrides
│       └── external-secrets/
│           ├── cluster-secret-store.yaml                # ClusterSecretStore → AWS Secrets Manager
│           └── nodeapp-production-external-secret.yaml  # ExternalSecret → nodeapp-db-secret
│
├── terraform/
│   ├── main.tf                     # Root module wiring all submodules
│   ├── outputs.tf
│   ├── varaibles.tf
│   └── modules/
│       ├── vpc/                    # VPC, subnets, NAT gateways
│       ├── eks/                    # EKS cluster, managed node group, OIDC provider
│       ├── eks-addons/             # EBS CSI driver (IRSA + addon)
│       ├── rds/                    # RDS PostgreSQL, Secrets Manager secret, ESO IRSA role
│       ├── elastic-cache/          # ElastiCache Serverless (Redis) for dev and prod
│       ├── alb/                    # AWS Load Balancer Controller (IRSA + Helm)
│       ├── route53/                # ExternalDNS (IRSA + Helm), hosted zone
│       └── argocd/                 # ArgoCD + Argo Rollouts (Helm)
│
└── .github/workflows/
    ├── dockerbuild.yml                  # Build & push Docker image to GHCR
    ├── helmchart.yml                    # Package Helm chart → GitHub Pages (Helm repo)
    ├── release-promotion.yml            # Tag release image, update production values
    ├── deploy-argocd-application.yml    # Apply ArgoCD resources + ESO manifests
    ├── terraform-apply.yml              # Provision / update infrastructure
    └── terraform-destroy.yml           # Tear down infrastructure
```

### AWS Infrastructure

| Component | Service | Purpose |
|---|---|---|
| Compute | EKS (managed node group) | Runs all workloads |
| Ingress | AWS ALB (Load Balancer Controller) | Exposes services via ALB |
| DNS | Route53 + ExternalDNS | Auto-creates DNS records (`prod.sajil.click`) |
| Cache | ElastiCache Serverless (Redis) | Visit counter storage |
| Database | RDS PostgreSQL | Connectivity health check (`/db` endpoint) |
| Secrets | AWS Secrets Manager | Stores RDS credentials |
| Secret sync | External Secrets Operator | Syncs Secrets Manager → Kubernetes secret |
| Registry | GitHub Container Registry (GHCR) | Stores Docker images |
| Helm repo | GitHub Pages | Hosts packaged Helm charts |

---

## Project Overview & Data Flow

### Application

The Node.js app (`application/app.js`) exposes three endpoints:

| Endpoint | What it does |
|---|---|
| `GET /` | Reads and increments `numVisits` in Redis; returns hostname + visit count |
| `GET /db` | Runs `SELECT NOW()` against PostgreSQL; confirms DB connectivity |
| `GET /metrics` | Exposes Prometheus metrics (HTTP counters, memory gauge, visit counter) |

### Request Data Flow

```
Internet
   │
   ▼
AWS ALB  (shared ALB, group: shared-alb)
   │
   ▼
Nginx pod  (reverse proxy, namespace: nodeapp-production)
   │
   ▼
Node.js pod  ──────► ElastiCache Redis  (visit counter: numVisits)
   │
   └──────────────► RDS PostgreSQL  (health check only — SELECT NOW())
```

### Secret Provisioning Flow

```
Terraform apply
   │
   ├─► Creates RDS instance
   ├─► Stores credentials in AWS Secrets Manager  (nodeapp-db-credentials-v3)
   └─► Creates IAM Role EKS-ESO-IRSA  (trust: ESO service account via OIDC/IRSA)

External Secrets Operator  (namespace: external-secrets)
   │  authenticates to AWS using IRSA
   ▼
ClusterSecretStore (aws-secrets-manager)
   │  reads from Secrets Manager
   ▼
ExternalSecret (nodeapp-db-secret in nodeapp-production)
   │  refreshes every 1 hour
   ▼
Kubernetes Secret: nodeapp-db-secret
   │  injected as env vars: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_SSL
   ▼
Node.js pod
```

### Deployment Flow (GitOps)

```
Code push to main (application/**)
   │
   ▼
dockerbuild.yml  ──► builds image ──► pushes ghcr.io/sajilpb/ibs-gitops-platform:<sha>

   │  (on GitHub Release published)
   ▼
release-promotion.yml
   ├─► re-tags image as <release-version> and pushes to GHCR
   └─► updates gitops/argocd-applications/production/values.yaml
          │
          ▼  (git push triggers ArgoCD sync)
       ArgoCD ApplicationSet
          │  detects values.yaml diff
          ▼
       Argo Rollout  (canary strategy)
          │  20% → analysis → 30s pause → 50% → analysis → 30s pause → 100%
          ▼
       New version running in nodeapp-production
```

---

## GitHub Workflows

### 1. `dockerbuild.yml` — Build & Push Docker Image

**Trigger:** Push to `main` touching `application/**`, or manual dispatch.

Builds the Docker image from `application/Dockerfile` and pushes two tags to GHCR:
- `ghcr.io/sajilpb/ibs-gitops-platform:<full-sha>` — pinned tag used by ArgoCD
- Metadata tags (branch, PR number, etc.) via `docker/metadata-action`

Also generates a provenance attestation for supply-chain security.

---

### 2. `helmchart.yml` — Publish Helm Chart

**Trigger:** Push to `main` touching `helm/charts/**` or `helm/docs/index.yaml`, or manual dispatch.

Packages the `nodeapp` Helm chart, regenerates `helm/docs/index.yaml`, and deploys it to GitHub Pages at:
```
https://sajilpb.github.io/ibs-gitops-platform
```
This makes the chart installable via:
```bash
helm repo add nodeapp https://sajilpb.github.io/ibs-gitops-platform
helm install nodeapp nodeapp/nodeapp
```

---

### 3. `release-promotion.yml` — Promote to Production

**Trigger:** GitHub Release published, or manual dispatch with a version string (e.g. `v1.1.0`).

1. Pulls the latest image from GHCR (built from `main`)
2. Re-tags it with the release version and pushes to GHCR
3. Updates `gitops/argocd-applications/production/values.yaml` with the new image tag
4. Commits and pushes — ArgoCD detects the diff and triggers a canary rollout automatically

---

### 4. `deploy-argocd-application.yml` — Deploy ArgoCD Resources

**Trigger:** Push touching `gitops/argocd-applications/**`, or manual dispatch.

Connects to EKS via OIDC (role: `aws-github-role`) and applies:
1. **ArgoCD ingress** — exposes the ArgoCD UI via ALB
2. **External Secrets resources** — `ClusterSecretStore` and `ExternalSecret` to sync DB credentials into `nodeapp-production`
3. **ArgoCD ApplicationSet** — registers the application in ArgoCD, pointing at the Helm chart in this repo

---

### 5. `terraform-apply.yml` — Provision Infrastructure

**Trigger:** Manual dispatch only.

Runs `terraform fmt` → `terraform validate` → `tfsec` (security scan, results uploaded to GitHub Security tab) → `terraform apply -auto-approve`.

After apply, installs the External Secrets Operator via Helm with the correct IRSA role ARN read from Terraform output (`external_secrets_role_arn`).

---

### 6. `terraform-destroy.yml` — Destroy Infrastructure

**Trigger:** Manual dispatch only.

Runs `terraform destroy -auto-approve`. Tears down all AWS resources managed by Terraform.

---

## Environment URLs

| Environment | URL |
|---|---|
| Production app | `https://prod.sajil.click` |
| Helm chart repo | `https://sajilpb.github.io/ibs-gitops-platform` |
