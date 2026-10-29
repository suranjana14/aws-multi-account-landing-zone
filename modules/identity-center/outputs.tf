output "permission_set_arns" {
  description = "Permission set ARNs keyed by name."
  value       = { for k, ps in aws_ssoadmin_permission_set.this : k => ps.arn }
}
