output "operator_role_arn" {
  description = "ARN of the operator role that Apprentice-Final can assume."
  value       = aws_iam_role.project_operator.arn
}

output "assume_role_policy_arn" {
  description = "ARN of the policy attached to the Apprentice-Final user that allows assuming the operator role."
  value       = aws_iam_policy.assume_operator_role.arn
}


