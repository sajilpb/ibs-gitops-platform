variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "eks_security_group_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "nodeappdb"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "15.4"
}

variable "db_password_length" {
  type    = number
  default = 24
}

variable "secrets_manager_secret_name" {
  type    = string
  default = "nodeapp-db-credentials"
}
