variable "location" {
  type    = string
  default = "westeurope"
}

variable "dns_zone_name" {
  type    = string
  default = "biroltilki.art"
}

variable "kubernetes_version" {
  type        = string
  description = "Pin to a supported patch version in your Azure region (see `az aks get-versions --location <region>`). Leave null to use the region default from Terraform."
  default     = null
  nullable    = true
}

variable "api_server_authorized_ip_ranges" {
  type        = list(string)
  default     = []
  description = "CIDRs allowed to reach the API server; empty uses provider defaults"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "boutique"
    managedBy  = "terraform"
    costCenter = "personal-demo"
    env        = "shared"
  }
}

variable "owner_email" {
  type        = string
  description = "Tagged on resources (architecture §15)"
  default     = "btilki@gmail.com"
}
