variable "name" {
  description = "Name prefix."
  type        = string
  default     = "shared"
}

variable "vpc_cidr" {
  description = "CIDR for the shared egress/services VPC."
  type        = string
  default     = "10.0.0.0/22"
}

variable "az_count" {
  description = "Number of AZs."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "enable_nat_gateway" {
  description = "Centralized egress via NAT in this VPC (spokes route 0.0.0.0/0 to the TGW)."
  type        = bool
  default     = true
}

variable "organization_arn" {
  description = "Organization ARN; the Transit Gateway is shared with the whole org through RAM."
  type        = string
}

variable "spoke_cidr_supernet" {
  description = "Supernet covering all workload VPCs (used for return routes from the egress VPC)."
  type        = string
  default     = "10.0.0.0/8"
}

variable "flow_log_bucket_arn" {
  description = "Central log archive bucket ARN for VPC flow logs. Null disables flow logs."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
