variable "bucket_name" {
  description = "Globally unique name for the central log archive bucket."
  type        = string
}

variable "organization_id" {
  description = "Organization ID; only principals/sources in this org may write."
  type        = string
}

variable "management_account_id" {
  description = "Management account ID (owner of the organization CloudTrail trail)."
  type        = string
}

variable "org_trail_name" {
  description = "Name of the organization trail allowed to write to this bucket."
  type        = string
  default     = "org-trail"
}

variable "transition_to_glacier_days" {
  description = "Days before log objects move to Glacier Flexible Retrieval."
  type        = number
  default     = 90
}

variable "expiration_days" {
  description = "Days before log objects expire. Regulated workloads commonly keep 1–7 years."
  type        = number
  default     = 2555 # ~7 years
}

variable "enable_object_lock" {
  description = "Enable S3 Object Lock (governance mode) for WORM retention. Can only be set at bucket creation."
  type        = bool
  default     = false
}

variable "object_lock_days" {
  description = "Default Object Lock retention when enabled."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
