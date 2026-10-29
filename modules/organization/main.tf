################################################################################
# Organization
################################################################################

resource "aws_organizations_organization" "this" {
  count = var.create_organization ? 1 : 0

  feature_set = "ALL"

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "access-analyzer.amazonaws.com",
    "sso.amazonaws.com",
    "ram.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com",
  ]

  enabled_policy_types = ["SERVICE_CONTROL_POLICY", "TAG_POLICY"]
}

data "aws_organizations_organization" "existing" {
  count = var.create_organization ? 0 : 1
}

locals {
  root_id = var.create_organization ? aws_organizations_organization.this[0].roots[0].id : data.aws_organizations_organization.existing[0].roots[0].id
  org_id  = var.create_organization ? aws_organizations_organization.this[0].id : data.aws_organizations_organization.existing[0].id
}

################################################################################
# Organizational units
################################################################################

resource "aws_organizations_organizational_unit" "this" {
  for_each = var.organizational_units

  name      = each.value.name
  parent_id = local.root_id
  tags      = var.tags
}

################################################################################
# Service control policies
################################################################################

resource "aws_organizations_policy" "scp" {
  for_each = var.service_control_policies

  name        = each.key
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.content
  tags        = var.tags
}

locals {
  ou_attachments = merge([
    for ou_key, ou in var.organizational_units : {
      for scp in ou.scps : "${ou_key}/${scp}" => { ou = ou_key, scp = scp }
    }
  ]...)
}

resource "aws_organizations_policy_attachment" "root" {
  for_each = toset(var.root_scps)

  policy_id = aws_organizations_policy.scp[each.value].id
  target_id = local.root_id
}

resource "aws_organizations_policy_attachment" "ou" {
  for_each = local.ou_attachments

  policy_id = aws_organizations_policy.scp[each.value.scp].id
  target_id = aws_organizations_organizational_unit.this[each.value.ou].id
}

################################################################################
# Account vending (optional)
################################################################################

resource "aws_organizations_account" "this" {
  for_each = var.accounts

  name              = each.value.name
  email             = each.value.email
  parent_id         = aws_organizations_organizational_unit.this[each.value.ou].id
  role_name         = each.value.role_name
  close_on_deletion = false

  # Changing role_name after creation forces replacement; the attribute is not readable.
  lifecycle {
    ignore_changes = [role_name]
  }

  tags = merge(var.tags, { OU = each.value.ou })
}
