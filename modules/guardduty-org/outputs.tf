output "detector_id" {
  description = "GuardDuty detector in the delegated admin account."
  value       = aws_guardduty_detector.this.id
}

output "findings_topic_arn" {
  description = "SNS topic receiving high-severity findings."
  value       = aws_sns_topic.findings.arn
}
