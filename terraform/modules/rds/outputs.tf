output "db_endpoint" {
  value = aws_db_instance.default.address
}

output "db_port" {
  value = aws_db_instance.default.port
}

output "db_name" {
  value = aws_db_instance.default.db_name
}

output "db_username" {
  value = aws_db_instance.default.username
}

output "sm_secret_name" {
  value = aws_secretsmanager_secret.db_credentials.name
}

output "sm_secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}

output "eso_irsa_role_arn" {
  description = "IAM Role ARN for External Secrets Operator IRSA"
  value       = aws_iam_role.eso_irsa.arn
}
