variable "project_name" {
  description = "Name prefix for tags/resources."
  type        = string
  default     = "nbn"
}

variable "vpc_cidr" {
  description = "RFC1918 IPv4 CIDR for the VPC (must be large enough to split into 32 subnets)."
  type        = string

  validation {
    condition = can(regex(
      // RFC1918: 10.0.0.0/8  OR 172.16.0.0/12  OR 192.168.0.0/16
      "^(10\\.(?:\\d{1,3}\\.){2}\\d{1,3}/\\d{1,2})$|^(172\\.(1[6-9]|2[0-9]|3[0-1])\\.(?:\\d{1,3})\\.(?:\\d{1,3})/\\d{1,2})$|^(192\\.168\\.(?:\\d{1,3})\\.(?:\\d{1,3})/\\d{1,2})$",
      var.vpc_cidr
    ))
    error_message = "vpc_cidr must be RFC1918 (10.0.0.0/8, 172.16.0.0/12, or 192.168.0.0/16)."
  }
}

variable "enable_internet_gateway" {
  description = "Create and attach an Internet Gateway for public subnets."
  type        = bool
  default     = true
}

variable "enable_egress_only_igw" {
  description = "Create an Egress-Only Internet Gateway for private IPv6 egress."
  type        = bool
  default     = true
}

variable "nat_mode" {
  description = "NAT strategy for private IPv4 egress. Options: none | single (default)."
  type        = string
  default     = "single"
  validation {
    condition     = contains(["none", "single"], var.nat_mode)
    error_message = "nat_mode must be one of: none, single."
  }
}

variable "tags" {
  description = "Extra tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# Optional pinning for IPv6 network border group (usually leave empty)
variable "ipv6_network_border_group" {
  description = "Optional network border group for IPv6 block (defaults to region)."
  type        = string
  default     = null
}
