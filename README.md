# IBS GitOps Platform

A production-grade GitOps platform running a Node.js application on AWS EKS, using ArgoCD for continuous delivery, Argo Rollouts for canary deployments, and the External Secrets Operator to sync AWS Secrets Manager credentials into Kubernetes.

---

## Table of Contents

- [Repository Architecture](#repository-architecture)
- [AWS Infrastructure](#aws-infrastructure)
- [Project Overview & Data Flow](#project-overview--data-flow)
- [GitHub Workflows](#github-workflows)
- [Environment URLs](#environment-urls)

---

## Repository Architecture

```
ibs-gitops-platform/
├── application/                    # Node.js application source
│   ├── app.js                      # Express app (visit counter, DB health check)
│   └── Dockerfile
│
├── helm/
│   └── charts/nodeapp/             # Helm chart — owns all application resources
│       ├── Chart.yaml
│       ├── values.yaml             # Default values (all features disabled)
│       └── templates/
│           ├── node-deployment.yaml        # Argo Rollout (canary strategy)
│           ├── nginx-deployment.yaml       # Nginx reverse proxy
│           ├── ingress.yaml                # App ALB ingress (prod.sajil.click)
│           ├── argocd-ingress.yaml         # ArgoCD UI ALB ingress (argocd.sajil.click)
│           ├── cluster-secret-store.yaml   # ESO ClusterSecretStore → AWS Secrets Manager
│           ├── external-secret.yaml        # ESO ExternalSecret → nodeapp-db-secret
│           ├── analysis-template.yaml      # Canary analysis (CloudWatch ALB metrics)
│           ├── hpa.yaml                    # Horizontal Pod Autoscaler
│           ├── nginx-configmap.yaml
│           ├── nginx-service.yaml
│           ├── node-service.yaml
│           └── redis-deployment.yaml
│
├── gitops/
│   └── argocd-applications/
│       ├── applicationset.yaml           # ArgoCD ApplicationSet (multi-env generator)
│       ├── production/
│       │   └── values.yaml              # Production overrides (image, secrets, ingress)
│       └── development/
│           └── values.yaml              # Development overrides
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
│       ├── elastic-cache/          # ElastiCache Serverless (Redis)
│       ├── alb/                    # AWS Load Balancer Controller (IRSA + Helm)
│       ├── route53/                # ExternalDNS (IRSA + Helm)
│       ├── argocd/                 # ArgoCD + Argo Rollouts (Helm + IRSA for CloudWatch)
│       └── cloudwatch/             # Route53 health checks + CloudWatch alarms
│
└── .github/workflows/
    ├── dockerbuild.yml                  # Build & push Docker image to GHCR
    ├── helmchart.yml                    # Package Helm chart → GitHub Pages
    ├── release-promotion.yml            # Tag release image, update production values
    ├── deploy-argocd-application.yml    # Install ESO + apply ArgoCD ApplicationSet
    ├── terraform-apply.yml              # Provision / update infrastructure
    └── terraform-destroy.yml           # Tear down infrastructure
```

---

## AWS Infrastructure

| Component | Service | Purpose |
|---|---|---|
| Compute | EKS (managed node group) | Runs all workloads |
| Ingress | AWS ALB (shared, group: `shared-alb`) | Single ALB routes both app and ArgoCD UI traffic |
| DNS | Route53 + ExternalDNS | Auto-creates DNS records for `*.sajil.click` |
| Cache | ElastiCache Serverless (Redis) | Visit counter storage |
| Database | RDS PostgreSQL | Connectivity health check (`/db` endpoint) |
| Secrets | AWS Secrets Manager (`nodeapp-db-credentials-v4`) | Stores RDS credentials |
| Secret sync | External Secrets Operator (IRSA: `EKS-ESO-IRSA`) | Syncs Secrets Manager → `nodeapp-db-secret` |
| Canary analysis | CloudWatch (`AWS/ApplicationELB`) | Gates canary promotion on error rate and P95 latency |
| Endpoint monitoring | CloudWatch + Route53 health checks | Alarms on `prod.sajil.click` availability |
| CD | ArgoCD | GitOps sync of Helm chart from this repo |
| Canary delivery | Argo Rollouts (IRSA: `EKS-ArgoRollouts-IRSA`) | Progressive traffic shifting with CloudWatch analysis |
| Registry | GitHub Container Registry (GHCR) | Stores Docker images |
| Helm repo | GitHub Pages | Hosts packaged Helm charts |

---

## Project Overview & Data Flow

### Application

The Node.js app (`application/app.js`) exposes two endpoints:

| Endpoint | What it does |
|---|---|
| `GET /` | Reads and increments `numVisits` in Redis; returns hostname + visit count |
| `GET /db` | Runs `SELECT NOW()` against PostgreSQL; confirms DB connectivity |

### Request Data Flow

```
Internet
   │
   ▼
AWS ALB  (shared ALB — group: shared-alb)
   ├──► argocd.sajil.click  → ArgoCD server (namespace: argocd)
   └──► prod.sajil.click    → Nginx pod     (namespace: nodeapp-production)
                                  │
                                  ▼
                            Node.js pod ──────► ElastiCache Redis  (visit counter)
                                  │
                                  └──────────► RDS PostgreSQL      (health check)
```

### Secret Provisioning Flow

```
terraform-apply.yml
   │
   ├─► Creates RDS instance
   ├─► Stores credentials in Secrets Manager  (nodeapp-db-credentials-v4)
   └─► Creates IAM Role EKS-ESO-IRSA  (OIDC trust: external-secrets/external-secrets SA)

deploy-argocd-application.yml
   │
   └─► Installs External Secrets Operator via Helm
          │  annotates SA with EKS-ESO-IRSA role ARN
          ▼
       ArgoCD syncs Helm chart
          │
          ├─► ClusterSecretStore (aws-secrets-manager)  ← authenticates via IRSA
          └─► ExternalSecret (nodeapp-db-secret)        ← reads from Secrets Manager
                 │  refreshes every 1 hour
                 ▼
             Kubernetes Secret: nodeapp-db-secret
                 │  keys: host, port, name, username, password, ssl
                 ▼
             Node.js pod env vars: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_SSL
```

### Deployment & Canary Flow

```
Code push to main (application/**)
   │
   ▼
dockerbuild.yml
   └─► builds image → ghcr.io/sajilpb/ibs-gitops-platform:<sha>

GitHub Release published (or workflow_dispatch)
   │
   ▼
release-promotion.yml
   ├─► re-tags image as <release-version> → GHCR
   └─► updates gitops/argocd-applications/production/values.yaml (image tag)
          │
          ▼  (git push → ArgoCD detects diff → automated sync)
       Argo Rollout  (canary strategy)
          │
          ├─► 20% canary traffic
          │     └─► CloudWatch analysis (3 min)
          │           ├─► HTTPCode_Target_5XX_Count / RequestCount  ≤ 1% → pass
          │           └─► TargetResponseTime p95                    < 300ms → pass
          ├─► pause 30s
          ├─► 50% canary traffic
          │     └─► CloudWatch analysis (3 min)
          ├─► pause 30s
          └─► 100%  (promotion complete)
              ✗ if analysis fails → automatic rollback to stable
```

> **Note:** CloudWatch canary analysis requires `canary.cloudwatch.albArnSuffix` to be set in `gitops/argocd-applications/production/values.yaml`. Get the value with:
> ```bash
> aws elbv2 describe-load-balancers \
>   --query "LoadBalancers[?contains(LoadBalancerName,'sharedal')].LoadBalancerArn" \
>   --output text | sed 's|.*loadbalancer/||'
> ```
> When empty, the rollout proceeds through pause steps only (no automatic rollback on errors).

---

## GitHub Workflows

### 1. `dockerbuild.yml` — Build & Push Docker Image

**Trigger:** Push to `main` touching `application/**`, or manual dispatch.

Builds the Docker image from `application/Dockerfile` and pushes to GHCR:
- `ghcr.io/sajilpb/ibs-gitops-platform:<full-sha>` — pinned tag used by ArgoCD
- Metadata tags via `docker/metadata-action`

Also generates a provenance attestation for supply-chain security.

---

### 2. `helmchart.yml` — Publish Helm Chart

**Trigger:** Push to `main` touching `helm/charts/**` or `helm/docs/index.yaml`, or manual dispatch.

Packages the `nodeapp` Helm chart, regenerates `helm/docs/index.yaml`, and deploys it to GitHub Pages:
```
https://sajilpb.github.io/ibs-gitops-platform
```
```bash
helm repo add nodeapp https://sajilpb.github.io/ibs-gitops-platform
helm install nodeapp nodeapp/nodeapp
```

---

### 3. `release-promotion.yml` — Promote to Production

**Trigger:** GitHub Release published, or manual dispatch with a version string (e.g. `v1.1.0`).

1. Pulls the latest `main` image from GHCR
2. Re-tags it with the release version and pushes to GHCR
3. Updates `gitops/argocd-applications/production/values.yaml` with the new image tag
4. Commits and pushes — ArgoCD detects the diff and triggers a canary rollout automatically

---

### 4. `deploy-argocd-application.yml` — Deploy ArgoCD Resources

**Trigger:** Push touching `gitops/argocd-applications/**`, or manual dispatch.

Connects to EKS via OIDC (`aws-github-role`) and runs in order:

1. **Install ESO** — `helm upgrade --install external-secrets` with the `EKS-ESO-IRSA` role ARN fetched from AWS IAM (`aws iam get-role`)
2. **Wait for CRDs** — `kubectl wait --for=condition=established` on all ESO CRDs before proceeding
3. **Apply ApplicationSet** — ArgoCD takes ownership of the Helm chart, which includes the app ingress, ArgoCD UI ingress, `ClusterSecretStore`, and `ExternalSecret`
4. **Force sync** — annotates the application with `argocd.argoproj.io/refresh=hard` to trigger an immediate sync

The `ClusterSecretStore`, `ExternalSecret`, and both ALB ingresses are all managed inside the Helm chart — no standalone kubectl-applied manifests.

---

### 5. `terraform-apply.yml` — Provision Infrastructure

**Trigger:** Manual dispatch only.

Runs `terraform fmt` → `terraform validate` → `tfsec` (results uploaded to GitHub Security tab) → `terraform apply -auto-approve`.

Key resources provisioned:
- VPC, EKS cluster, RDS, ElastiCache, ALB controller, ExternalDNS, ArgoCD, Argo Rollouts
- IAM roles: `EKS-ESO-IRSA` (ESO → Secrets Manager), `EKS-ArgoRollouts-IRSA` (Argo Rollouts → CloudWatch)
- Route53 health check on `prod.sajil.click` + CloudWatch alarm

After apply, installs ESO via Helm with the correct IRSA annotation (role ARN from `terraform output -raw external_secrets_role_arn`).

---

### 6. `terraform-destroy.yml` — Destroy Infrastructure

**Trigger:** Manual dispatch only.

Runs `terraform destroy -auto-approve`. Tears down all AWS resources managed by Terraform.

---

## Environment URLs

| Environment | URL |
|---|---|
| Production app | `https://prod.sajil.click` |
| ArgoCD UI | `https://argocd.sajil.click` |
| Helm chart repo | `https://sajilpb.github.io/ibs-gitops-platform` |
