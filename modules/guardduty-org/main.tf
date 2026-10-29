# Runs in the Security (audit) account after the management account has made
# it the delegated administrator:
#   aws_guardduty_organization_admin_account / aws_securityhub_organization_admin_account
# (see envs/sandbox/main.tf).

data "aws_region" "current" {}
data "aws_partition" "current" {}

resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = var.finding_publishing_frequency
  tags                         = var.tags
}

resource "aws_guardduty_organization_configuration" "this" {
  detector_id                      = aws_guardduty_detector.this.id
  auto_enable_organization_members = var.auto_enable_members
}

resource "aws_guardduty_organization_configuration_feature" "s3" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  auto_enable = var.auto_enable_members
}

resource "aws_guardduty_organization_configuration_feature" "eks_audit" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  auto_enable = var.auto_enable_members
}

resource "aws_guardduty_organization_configuration_feature" "malware" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EBS_MALWARE_PROTECTION"
  auto_enable = var.auto_enable_members
}

################################################################################
# Security Hub aggregation
################################################################################

resource "aws_securityhub_account" "this" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards = false
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  count = var.enable_security_hub ? 1 : 0

  standards_arn = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}

resource "aws_securityhub_organization_configuration" "this" {
  count = var.enable_security_hub ? 1 : 0

  auto_enable           = true
  auto_enable_standards = "DEFAULT"
  depends_on            = [aws_securityhub_account.this]
}

################################################################################
# High-severity findings -> SNS
################################################################################

resource "aws_sns_topic" "findings" {
  name = "security-findings-high"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.findings_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.findings.arn
  protocol  = "email"
  endpoint  = var.findings_email
}

resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "guardduty-high-severity"
  description = "GuardDuty findings with severity >= 7 from any member account"
  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail        = { severity = [{ numeric = [">=", 7] }] }
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "guardduty_high" {
  rule = aws_cloudwatch_event_rule.guardduty_high.name
  arn  = aws_sns_topic.findings.arn
}

resource "aws_sns_topic_policy" "findings" {
  arn = aws_sns_topic.findings.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridge"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.findings.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.guardduty_high.arn } }
    }]
  })
}
