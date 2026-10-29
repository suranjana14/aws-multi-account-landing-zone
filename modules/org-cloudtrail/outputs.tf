output "trail_arn" {
  description = "Organization trail ARN."
  value       = aws_cloudtrail.org.arn
}

output "cis_metric_names" {
  description = "Metric names (namespace LandingZone/CISBenchmark) available for alarms."
  value       = keys(aws_cloudwatch_log_metric_filter.cis)
}
