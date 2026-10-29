variable "trail_name" {
  description = "Organization trail name (must match the name allowed in the log archive bucket policy)."
  type        = string
  default     = "org-trail"
}

variable "s3_bucket_name" {
  description = "Central log archive bucket."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key for log file encryption."
  type        = string
}

variable "cloudwatch_logs_retention_days" {
  description = "Retention for the CloudWatch Logs copy used for near-real-time alerting. 0 disables the copy."
  type        = number
  default     = 90
}

variable "log_data_events_for_buckets" {
  description = "S3 bucket ARNs whose object-level (data) events are logged, e.g. buckets holding regulated data."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
