# Create addition roles for load balancer service account.

resource "aws_iam_policy" "additional" {
  name        = "additionol_lb_roles"
  path        = "/"
  description = "additionol_lb_roles"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeRouteTables",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:SetRulePriorities"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Load balancer role
module "lb_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.28.0"

  role_name                              = "${var.env_name}_eks_lb"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  role_policy_arns = {
    additional = aws_iam_policy.additional.arn
  }
}

# Load balancer service account
resource "kubernetes_service_account" "service-account" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

# Install Load Balancer Controler With Helm
################################################################################

resource "helm_release" "lb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    kubernetes_service_account.service-account
  ]

  set = [
    {
      name  = "region"
      value = var.main-region
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "image.repository"
      value = "602401143452.dkr.ecr.${var.main-region}.amazonaws.com/amazon/aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "clusterName"
      value = var.cluster_name
    }
  ]
}

