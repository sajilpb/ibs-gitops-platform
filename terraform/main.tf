################################################################
# VPC Module
################################################################
module "vpc" {
  source = "./modules/vpc"
}

################################################################
# EKS Module
################################################################
module "eks" {
  source               = "./modules/eks"
  subnet_ids           = module.vpc.private_subnets
  vpc_id               = module.vpc.vpc_id
  aws_eks_cluster_name = var.cluster_name
}


# ################################################################
# # ALB Module
# ################################################################
module "alb" {
  source            = "./modules/alb"
  main-region       = var.main-region
  env_name          = var.env_name
  cluster_name      = var.cluster_name
  depends_on        = [module.eks]
  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
}

################################################################
# Route53 Module
################################################################
module "route53" {
  source            = "./modules/route53"
  domain_name       = var.domain_name
  depends_on        = [module.eks]
  oidc_provider_arn = module.eks.oidc_provider_arn
  cluster_name      = var.cluster_name
  oidc_provider_url = module.eks.cluster_oidc_issuer_url
}

################################################################
# Argo Module
################################################################
module "argocd" {
  source       = "./modules/argocd"
  cluster_name = var.cluster_name
  main-region  = var.main-region
  vpc_id       = module.vpc.vpc_id
  depends_on   = [module.eks, module.route53]
}

#########################################
# IAM Role for EBS CSI Driver (IRSA)
#########################################
module "csiaddon" {
  source            = "./modules/eks-addons"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url
  cluster_name      = var.cluster_name
}

#########################################
# Elastic Cache Module
#########################################
module "elastic-cache"{
  source = "./modules/elastic-cache"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets
  source_security_group_id = module.eks.node_security_group_id
}

#########################################
# Promethius and Grafana stack
#########################################
module "monitoring" {
  source     = "git::https://github.com/sajilpb/Promethius.Grafana.stack.git"
  depends_on = [module.csiaddon, module.eks]
}