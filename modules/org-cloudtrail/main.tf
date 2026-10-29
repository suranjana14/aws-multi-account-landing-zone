locals {
  cw_enabled = var.cloudwatch_logs_retention_days > 0
}

resource "aws_cloudwatch_log_group" "trail" {
  count = local.cw_enabled ? 1 : 0

  name              = "/org/cloudtrail/${var.trail_name}"
  retention_in_days = var.cloudwatch_logs_retention_days
  tags              = var.tags
}

data "aws_iam_policy_document" "trail_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "trail_to_cw" {
  count = local.cw_enabled ? 1 : 0

  name               = "${var.trail_name}-to-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.trail_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "trail_to_cw" {
  count = local.cw_enabled ? 1 : 0

  name = "write-logs"
  role = aws_iam_role.trail_to_cw[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.trail[0].arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "org" {
  name                          = var.trail_name
  s3_bucket_name                = var.s3_bucket_name
  s3_key_prefix                 = "cloudtrail"
  kms_key_id                    = var.kms_key_arn
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = local.cw_enabled ? "${aws_cloudwatch_log_group.trail[0].arn}:*" : null
  cloud_watch_logs_role_arn  = local.cw_enabled ? aws_iam_role.trail_to_cw[0].arn : null

  dynamic "event_selector" {
    for_each = length(var.log_data_events_for_buckets) > 0 ? [1] : []

    content {
      read_write_type           = "All"
      include_management_events = true

      data_resource {
        type   = "AWS::S3::Object"
        values = [for arn in var.log_data_events_for_buckets : "${arn}/"]
      }
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy.trail_to_cw]
}

################################################################################
# CIS-style alerting on the trail (root usage, IAM policy changes, console
# sign-in without MFA). Metric filters feed alarms owned by the security team.
################################################################################

locals {
  cis_filters = local.cw_enabled ? {
    RootAccountUsage       = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
    ConsoleSigninNoMfa     = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") && ($.userIdentity.type = \"IAMUser\") && ($.responseElements.ConsoleLogin = \"Success\") }"
    IamPolicyChanges       = "{ ($.eventSource = iam.amazonaws.com) && (($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = DeleteUserPolicy) || ($.eventName = PutGroupPolicy) || ($.eventName = PutRolePolicy) || ($.eventName = PutUserPolicy) || ($.eventName = CreatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = AttachRolePolicy) || ($.eventName = DetachRolePolicy)) }"
    CloudTrailConfigChange = "{ ($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging) }"
    SecurityGroupChanges   = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"
  } : {}
}

resource "aws_cloudwatch_log_metric_filter" "cis" {
  for_each = local.cis_filters

  name           = each.key
  log_group_name = aws_cloudwatch_log_group.trail[0].name
  pattern        = each.value

  metric_transformation {
    name      = each.key
    namespace = "LandingZone/CISBenchmark"
    value     = "1"
  }
}
