variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
}

variable "client_id" {
  description = "Service Principal Client ID"
  type        = string
}

variable "client_secret" {
  description = "Service Principal Client Secret"
  type        = string
  sensitive   = true
}

variable "resource_group_name" {
  description = "Resource group where Key Vaults will be created"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "source_keyvault_name" {
  description = "Name for the source Key Vault"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.source_keyvault_name))
    error_message = "Key Vault name must be 3-24 characters, start with a letter, and contain only alphanumeric characters and hyphens."
  }
}

variable "target_keyvault_name" {
  description = "Name for the target Key Vault"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.target_keyvault_name))
    error_message = "Key Vault name must be 3-24 characters, start with a letter, and contain only alphanumeric characters and hyphens."
  }
}

variable "sku_name" {
  description = "SKU name for Key Vault (standard or premium)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "SKU must be 'standard' or 'premium'."
  }
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain deleted vaults (7-90)"
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "Soft delete retention must be between 7 and 90 days."
  }
}

variable "purge_protection_enabled" {
  description = "Enable purge protection for Key Vaults"
  type        = bool
  default     = false
}

variable "enable_rbac_authorization" {
  description = "Use Azure RBAC for Key Vault access instead of access policies"
  type        = bool
  default     = false
}

variable "network_acls_default_action" {
  description = "Default network ACL action (Allow or Deny)"
  type        = string
  default     = "Allow"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_acls_default_action)
    error_message = "Network ACL default action must be 'Allow' or 'Deny'."
  }
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access Key Vaults"
  type        = list(string)
  default     = []
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access Key Vaults (CIDR notation)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
