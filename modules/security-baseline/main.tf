# Applied to every member account (loop it with a provider per account, or
# run it from a pipeline that assumes the account's admin role).

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# IAM
################################################################################

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = var.password_policy.minimum_length
  max_password_age               = var.password_policy.max_age_days
  password_reuse_prevention      = var.password_policy.reuse_prevention
  require_symbols                = var.password_policy.require_symbols
  require_numbers                = var.password_policy.require_numbers
  require_uppercase_characters   = var.password_policy.require_uppercase
  require_lowercase_characters   = var.password_policy.require_lowercase
  allow_users_to_change_password = var.password_policy.allow_users_to_change
  hard_expiry                    = false
}

resource "aws_iam_account_alias" "this" {
  count         = var.account_alias == null ? 0 : 1
  account_alias = var.account_alias
}

resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = "account-analyzer"
  type          = "ACCOUNT"
  tags          = var.tags
}

################################################################################
# Data protection defaults
################################################################################

resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

################################################################################
# AWS Config recorder -> central log archive
################################################################################

data "aws_iam_policy_document" "config_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  count = var.enable_config_recorder ? 1 : 0

  name               = "aws-config-recorder"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_config_recorder ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "this" {
  count = var.enable_config_recorder ? 1 : 0

  name     = "default"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = var.record_global_resources
  }
}

resource "aws_config_delivery_channel" "this" {
  count = var.enable_config_recorder ? 1 : 0

  name           = "default"
  s3_bucket_name = var.config_bucket_name
  s3_key_prefix  = "config"
  s3_kms_key_arn = var.config_kms_key_arn

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  count = var.enable_config_recorder ? 1 : 0

  name       = aws_config_configuration_recorder.this[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

# A small set of managed rules; at org scale these move to a conformance pack
# deployed from the security account.
locals {
  managed_rules = var.enable_config_recorder ? {
    "root-account-mfa-enabled"         = "ROOT_ACCOUNT_MFA_ENABLED"
    "iam-user-mfa-enabled"             = "IAM_USER_MFA_ENABLED"
    "s3-bucket-ssl-requests-only"      = "S3_BUCKET_SSL_REQUESTS_ONLY"
    "s3-bucket-server-side-encryption" = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    "encrypted-volumes"                = "ENCRYPTED_VOLUMES"
    "rds-storage-encrypted"            = "RDS_STORAGE_ENCRYPTED"
    "cloudtrail-enabled"               = "CLOUD_TRAIL_ENABLED"
    "vpc-flow-logs-enabled"            = "VPC_FLOW_LOGS_ENABLED"
    "restricted-ssh"                   = "INCOMING_SSH_DISABLED"
    "iam-no-inline-policy"             = "IAM_NO_INLINE_POLICY_CHECK"
  } : {}
}

resource "aws_config_config_rule" "managed" {
  for_each = local.managed_rules

  name = each.key

  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  tags = var.tags

  depends_on = [aws_config_configuration_recorder.this]
}
