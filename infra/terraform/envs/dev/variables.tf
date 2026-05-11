variable "location" {
  type    = string
  default = "westeurope"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "boutique"
    managedBy  = "terraform"
    costCenter = "personal-demo"
    env        = "dev"
  }
}

variable "owner_email" {
  type    = string
  default = "btilki@gmail.com"
}

variable "shared_state_resource_group_name" {
  type        = string
  description = "TF state RG (bootstrap output)"
}

variable "shared_state_storage_account_name" {
  type = string
}

variable "shared_state_container_name" {
  type    = string
  default = "tfstate-shared"
}

variable "shared_state_key" {
  type    = string
  default = "boutique-shared.tfstate"
}

# Object ID of the app behind Azure DevOps `promotion-azure-connection` (Enterprise application → Object ID).
# When set, grants AcrPull on dev ACR so `promote-to-stage` pre-check passes.
variable "promotion_service_principal_object_id" {
  type        = string
  default     = ""
  description = "Optional. Promotion pipeline SP object ID for AcrPull on dev ACR."
}
