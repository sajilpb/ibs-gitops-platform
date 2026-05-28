################################################################################
# Default Variables
################################################################################

variable "main-region" {
  type    = string
  default = "us-east-1"
}

################################################################################
# EKS Cluster Variables
################################################################################

variable "cluster_name" {
  type    = string
  default = "NodeApp"
}

variable "rolearn" {
  description = "Add admin role to the aws-auth configmap"
  default     = "yes"
}

################################################################################
# ALB Controller Variables
################################################################################

variable "env_name" {
  type    = string
  default = "dev"
}

################################################################################
# ECR Variables
################################################################################

variable "ecr_repository_name" {
  type    = string
  default = "devopsautomation"
}

################################################################################
# Codebuild Variables
################################################################################

variable "Codebuild-project-name" {
  type    = string
  default = "Node-app"
}

variable "Codebuild-project-name-description" {
  type    = string
  default = "Node-application-build"
}

variable "Source-repo" {
  type    = string
  default = "https://github.com/sajil143pb/AWS-codecommit.git"
}

variable "source-buildspec-file" {
  type    = string
  default = "02-Docker-image-pipeline/buildspec.yml"
}

variable "source-branch" {
  type    = string
  default = "main"
}

################################################################################
# Route53 Variables
################################################################################

variable "domain_name" {
  type    = string
  default = "sajil.click"
}
