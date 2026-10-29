variable "auto_enable_members" {
  description = "ALL enrolls every existing and new member account; NEW only future ones; NONE disables auto-enrollment."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "NEW", "NONE"], var.auto_enable_members)
    error_message = "auto_enable_members must be ALL, NEW, or NONE."
  }
}

variable "finding_publishing_frequency" {
  description = "How often updated findings are exported."
  type        = string
  default     = "FIFTEEN_MINUTES"
}

variable "enable_security_hub" {
  description = "Also enable Security Hub (with AWS Foundational Security Best Practices) in the delegated admin account."
  type        = bool
  default     = true
}

variable "findings_email" {
  description = "Optional email for high-severity findings (SNS). Empty disables the subscription."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
