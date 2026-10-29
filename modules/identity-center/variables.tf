variable "permission_sets" {
  description = "Permission sets keyed by name."
  type = map(object({
    description      = string
    session_duration = optional(string, "PT4H")
    managed_policies = list(string)
    inline_policy    = optional(string)
  }))
}

variable "assignments" {
  description = <<-EOT
    Group -> permission set -> account assignments. Groups come from the
    external IdP via SCIM; reference them by display name.
  EOT
  type = list(object({
    group          = string
    permission_set = string
    account_ids    = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags applied to permission sets."
  type        = map(string)
  default     = {}
}
