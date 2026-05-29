##############################################
# IRSA for Argo Rollouts (CloudWatch access)
##############################################

resource "aws_iam_role" "argo_rollouts_irsa" {
  name = "EKS-ArgoRollouts-IRSA"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:argocd:argo-rollouts"
          "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "argo_rollouts_cloudwatch" {
  name = "ArgoRolloutsCloudWatchPolicy"
  role = aws_iam_role.argo_rollouts_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics"
      ]
      Resource = "*"
    }]
  })
}

resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argocd"
  create_namespace = true

  set = [
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "argo-rollouts"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.argo_rollouts_irsa.arn
    },
    {
      name  = "dashboard.enabled"
      value = "true"
    },
    {
      name  = "dashboard.service.targetPort"
      value = "3100"
    },
    {
      name  = "dashboard.service.port"
      value = "3100"
    },
    {
      name  = "dashboard.service.portName"
      value = ""
    },
    {
      name  = "dashboard.containerPort"
      value = "3100"
    },
  ]
}

##############################################
# Argo CD Helm Installation on EKS (Terraform)
##############################################

# You should already have these:
# provider "aws" { ... }
# provider "kubernetes" { ... }
# provider "helm" { ... }


resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  version = "9.1.3"

  values = [
    file("${path.module}/templates/values-argocd.yaml")
  ]
}
