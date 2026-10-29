output "organization_id" {
  value = module.organization.organization_id
}

output "ou_ids" {
  value = module.organization.ou_ids
}

output "log_archive_bucket" {
  value = module.log_archive.bucket_name
}

output "org_trail_arn" {
  value = module.org_cloudtrail.trail_arn
}

output "guardduty_detector_id" {
  value = module.guardduty_org.detector_id
}

output "transit_gateway_id" {
  value = module.shared_network.transit_gateway_id
}

output "permission_set_arns" {
  value = module.identity_center.permission_set_arns
}
