locals {
  tags = {
    Project     = "landing-zone"
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }

  scp_dir = "${path.module}/../../policies/scp"
}

################################################################################
# 1. Organization, OUs, SCPs (management account)
################################################################################

module "organization" {
  source = "../../modules/organization"

  create_organization = var.create_organization

  service_control_policies = {
    deny-leave-organization = {
      description = "Accounts cannot leave the organization"
      content     = file("${local.scp_dir}/deny-leave-organization.json")
    }
    deny-root-user = {
      description = "Root user is break-glass only"
      content     = file("${local.scp_dir}/deny-root-user.json")
    }
    protect-security-services = {
      description = "CloudTrail, Config, GuardDuty, Security Hub cannot be disabled"
      content     = file("${local.scp_dir}/protect-security-services.json")
    }
    region-restriction = {
      description = "Only approved regions"
      content     = templatefile("${local.scp_dir}/region-restriction.json.tftpl", { allowed_regions = var.allowed_regions })
    }
    data-protection-baseline = {
      description = "Encryption-by-default and no IAM user keys"
      content     = file("${local.scp_dir}/data-protection-baseline.json")
    }
    sandbox-guardrails = {
      description = "Cost and connectivity guardrails for sandboxes"
      content     = file("${local.scp_dir}/sandbox-guardrails.json")
    }
  }

  root_scps = ["deny-leave-organization", "protect-security-services", "region-restriction"]

  organizational_units = {
    security       = { name = "Security", scps = ["deny-root-user"] }
    infrastructure = { name = "Infrastructure", scps = ["deny-root-user"] }
    workloads-prod = { name = "Workloads-Prod", scps = ["deny-root-user", "data-protection-baseline"] }
    workloads-dev  = { name = "Workloads-NonProd", scps = ["deny-root-user", "data-protection-baseline"] }
    sandbox        = { name = "Sandbox", scps = ["deny-root-user", "sandbox-guardrails"] }
    suspended      = { name = "Suspended", scps = [] }
  }

  # Account vending is modelled but left empty so `plan` never creates accounts by accident.
  # accounts = {
  #   log-archive = { name = "log-archive", email = "aws+log-archive@example.com", ou = "security" }
  #   security    = { name = "security",    email = "aws+security@example.com",    ou = "security" }
  #   network     = { name = "network",     email = "aws+network@example.com",     ou = "infrastructure" }
  # }

  tags = local.tags
}

################################################################################
# 2. Log archive account: central, immutable-by-policy log bucket
################################################################################

module "log_archive" {
  source    = "../../modules/log-archive"
  providers = { aws = aws.log_archive }

  bucket_name           = var.log_bucket_name
  organization_id       = module.organization.organization_id
  management_account_id = var.management_account_id
  org_trail_name        = "org-trail"
  enable_object_lock    = false # set true for WORM retention in regulated environments

  tags = local.tags
}

################################################################################
# 3. Organization CloudTrail (management account -> log archive)
################################################################################

module "org_cloudtrail" {
  source = "../../modules/org-cloudtrail"

  trail_name     = "org-trail"
  s3_bucket_name = module.log_archive.bucket_name
  kms_key_arn    = module.log_archive.kms_key_arn

  tags = local.tags
}

################################################################################
# 4. Security account: delegated admin for GuardDuty + Security Hub
################################################################################

resource "aws_guardduty_organization_admin_account" "security" {
  admin_account_id = var.account_ids.security
}

resource "aws_securityhub_organization_admin_account" "security" {
  admin_account_id = var.account_ids.security
}

module "guardduty_org" {
  source    = "../../modules/guardduty-org"
  providers = { aws = aws.security }

  auto_enable_members = "ALL"
  findings_email      = var.security_findings_email

  tags = local.tags

  depends_on = [
    aws_guardduty_organization_admin_account.security,
    aws_securityhub_organization_admin_account.security,
  ]
}

################################################################################
# 5. Network account: Transit Gateway hub + centralized egress
################################################################################

module "shared_network" {
  source    = "../../modules/shared-network"
  providers = { aws = aws.network }

  name                = "lz-sandbox"
  vpc_cidr            = "10.0.0.0/22"
  az_count            = 2
  enable_nat_gateway  = var.enable_nat_gateway
  organization_arn    = module.organization.organization_arn
  flow_log_bucket_arn = module.log_archive.bucket_arn

  tags = local.tags
}

################################################################################
# 6. Account baseline, applied to each member account (one shown here)
################################################################################

module "baseline_sandbox_workload" {
  source    = "../../modules/security-baseline"
  providers = { aws = aws.workload }

  account_alias      = "lz-sandbox-workload"
  config_bucket_name = module.log_archive.bucket_name
  config_kms_key_arn = module.log_archive.kms_key_arn

  tags = local.tags
}

################################################################################
# 7. Workforce access (IAM Identity Center, management account)
################################################################################

module "identity_center" {
  source = "../../modules/identity-center"

  permission_sets = {
    PlatformAdmin = {
      description      = "Landing zone administrators (break-glass excluded)"
      session_duration = "PT1H"
      managed_policies = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    }
    SecurityAudit = {
      description      = "Read-only security review across all accounts"
      managed_policies = ["arn:aws:iam::aws:policy/SecurityAudit", "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"]
    }
    Developer = {
      description      = "Workload engineers: PowerUser without IAM"
      managed_policies = ["arn:aws:iam::aws:policy/PowerUserAccess"]
    }
    ReadOnly = {
      description      = "Read-only support access"
      session_duration = "PT8H"
      managed_policies = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    }
  }

  assignments = [
    { group = "aws-platform-admins", permission_set = "PlatformAdmin", account_ids = values(var.account_ids) },
    { group = "aws-security", permission_set = "SecurityAudit", account_ids = values(var.account_ids) },
    { group = "aws-developers", permission_set = "Developer", account_ids = [var.account_ids.sandbox_workload] },
  ]

  tags = local.tags
}
