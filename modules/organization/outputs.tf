output "organization_id" {
  description = "Organization ID (o-xxxxxxxxxx); used in aws:SourceOrgID / aws:PrincipalOrgID conditions."
  value       = local.org_id
}

output "root_id" {
  description = "Root ID (r-xxxx)."
  value       = local.root_id
}

output "ou_ids" {
  description = "OU IDs keyed by short name."
  value       = { for k, ou in aws_organizations_organizational_unit.this : k => ou.id }
}

output "account_ids" {
  description = "Vended account IDs keyed by short name."
  value       = { for k, a in aws_organizations_account.this : k => a.id }
}

output "organization_arn" {
  description = "Organization ARN; used for RAM sharing."
  value       = var.create_organization ? aws_organizations_organization.this[0].arn : data.aws_organizations_organization.existing[0].arn
}
