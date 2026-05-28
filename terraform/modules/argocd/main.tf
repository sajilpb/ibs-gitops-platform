resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argocd"
  create_namespace = true

  set = [
    {
      name  = "serviceAccount.create"
      value = "false"
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
