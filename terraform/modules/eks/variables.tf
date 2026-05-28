variable "aws_eks_cluster_name" {
  type = string
}

# variables from other modules
variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(any)
}
