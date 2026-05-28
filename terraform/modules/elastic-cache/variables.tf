# variables from other modules
variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "source_security_group_id" {
  type = string
}

variable "redis_environments" {
  type = map(object({
    name = string
  }))

  default = {
    dev  = { name = "rediscache-nodeapp-dev" }
    prod = { name = "rediscache-nodeapp-prod" }
  }
}