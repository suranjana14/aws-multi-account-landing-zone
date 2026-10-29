variable "account_alias" {
  description = "Friendly account alias (shown on the sign-in page). Null skips it."
  type        = string
  default     = null
}

variable "config_bucket_name" {
  description = "Central log archive bucket that receives AWS Config snapshots/history."
  type        = string
}

variable "config_kms_key_arn" {
  description = "KMS key for Config delivery."
  type        = string
}

variable "enable_config_recorder" {
  description = "Turn on the AWS Config recorder in this account/region."
  type        = bool
  default     = true
}

variable "record_global_resources" {
  description = "Record IAM (global) resources. Enable in exactly one region per account."
  type        = bool
  default     = true
}

variable "password_policy" {
  description = "IAM password policy for any break-glass IAM users (workforce access goes through IAM Identity Center)."
  type = object({
    minimum_length        = number
    max_age_days          = number
    reuse_prevention      = number
    require_symbols       = bool
    require_numbers       = bool
    require_uppercase     = bool
    require_lowercase     = bool
    allow_users_to_change = bool
  })
  default = {
    minimum_length        = 14
    max_age_days          = 90
    reuse_prevention      = 24
    require_symbols       = true
    require_numbers       = true
    require_uppercase     = true
    require_lowercase     = true
    allow_users_to_change = true
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
