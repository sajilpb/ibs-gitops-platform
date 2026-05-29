variable "env_name" {
  description = "Environment name prefix for resource naming"
  type        = string
  default     = "nodeapp"
}

variable "prod_domain" {
  description = "Production application domain to monitor"
  type        = string
}

variable "alarm_actions" {
  description = "List of SNS topic ARNs to notify on alarm state changes"
  type        = list(string)
  default     = []
}
