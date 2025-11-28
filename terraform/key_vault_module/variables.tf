variable "keyvault_name" {
  type        = string
  description = "Name of the Key Vault"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group where Key Vault will be created"
}

variable "location" {
  type        = string
  description = "Location of Key Vault"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to enable Key Vault on"
}
