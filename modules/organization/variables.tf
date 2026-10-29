variable "create_organization" {
  description = "Create the AWS Organization. Set false to adopt an existing one (root ID is then read via a data source)."
  type        = bool
  default     = false
}

variable "organizational_units" {
  description = "Top-level OUs to create under the root, keyed by a short name."
  type = map(object({
    name = string
    scps = list(string) # keys of var.service_control_policies to attach
  }))
}

variable "service_control_policies" {
  description = "SCPs keyed by short name; content is a JSON policy document."
  type = map(object({
    description = string
    content     = string
  }))
  default = {}
}

variable "root_scps" {
  description = "SCP keys attached at the organization root (apply to every account except the management account)."
  type        = list(string)
  default     = []
}

variable "accounts" {
  description = <<-EOT
    Member accounts to vend, keyed by short name. Leave empty to model the
    layout without creating accounts (account creation needs unique real
    email addresses and cannot be undone quickly).
  EOT
  type = map(object({
    name      = string
    email     = string
    ou        = string # key of var.organizational_units
    role_name = optional(string, "OrganizationAccountAccessRole")
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to every taggable resource."
  type        = map(string)
  default     = {}
}
