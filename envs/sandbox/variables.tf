variable "home_region" {
  description = "Primary region for the landing zone."
  type        = string
  default     = "us-east-1"
}

variable "allowed_regions" {
  description = "Regions workloads may use (enforced by the region-restriction SCP)."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "create_organization" {
  description = "Create the organization (true) or adopt the existing one (false)."
  type        = bool
  default     = false
}

variable "management_account_id" {
  description = "Management (payer) account ID."
  type        = string
  default     = "111111111111"
}

variable "account_ids" {
  description = "Core account IDs. Placeholders let `terraform validate` run without real accounts."
  type = object({
    log_archive      = string
    security         = string
    network          = string
    sandbox_workload = string
  })
  default = {
    log_archive      = "222222222222"
    security         = "333333333333"
    network          = "444444444444"
    sandbox_workload = "555555555555"
  }
}

variable "cross_account_role_name" {
  description = "Role Terraform assumes in member accounts."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "log_bucket_name" {
  description = "Globally unique log archive bucket name."
  type        = string
  default     = "lz-sandbox-log-archive-222222222222"
}

variable "security_findings_email" {
  description = "Email for high-severity GuardDuty findings (optional)."
  type        = string
  default     = ""
}

variable "enable_nat_gateway" {
  description = "Centralized NAT egress (billable). Off by default in sandbox."
  type        = bool
  default     = false
}
