variable "env_name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

################################################################################
# Variables from other Modules
################################################################################

variable "vpc_id" {
  description = "VPC ID which EKS cluster is deployed in"
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "main-region" {
  type = string
}

