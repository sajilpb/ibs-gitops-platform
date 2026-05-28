# Data sources (unchanged)
data "aws_caller_identity" "current" {}

########### ECR Policy for Node Groups (simplified - removed duplicates) ###########
data "aws_iam_policy_document" "eks-policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "elasticloadbalancing:*",
      "ec2:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_ecr_policy" {
  name        = "EKS-ECR-Access"
  description = "Allow EKS worker nodes to pull images from ECR"
  policy      = data.aws_iam_policy_document.eks-policy.json
}


########### EKS Module (main fixes: removed circular access entry) ###########
module "eks" {
  source             = "terraform-aws-modules/eks/aws"
  version            = "21.9.0"
  name               = var.aws_eks_cluster_name
  kubernetes_version = "1.34"
  create_kms_key     = false
  enable_irsa        = true
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  encryption_config  = null

  create_cloudwatch_log_group = false
  endpoint_public_access      = true

  addons = {
    coredns                = { most_recent = true }
    eks-pod-identity-agent = { before_compute = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { before_compute = true }
  }

  enable_cluster_creator_admin_permissions = true

  # Attach ECR policy to node IAM role (unchanged)
  node_iam_role_additional_policies = {
    ecr_access = aws_iam_policy.eks_ecr_policy.arn
  }

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    NodeApp = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t2.large"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }

  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}