output "argo_rollouts_role_arn" {
  description = "IAM Role ARN for Argo Rollouts IRSA"
  value       = aws_iam_role.argo_rollouts_irsa.arn
}
