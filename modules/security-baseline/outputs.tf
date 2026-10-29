output "account_id" {
  description = "Account the baseline was applied to."
  value       = data.aws_caller_identity.current.account_id
}

output "config_rules" {
  description = "AWS Config managed rules enabled in this account."
  value       = keys(aws_config_config_rule.managed)
}
