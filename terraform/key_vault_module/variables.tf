variable "resource_group_name" {
  type        = string
  description = "Resource group where Key Vault will be created"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

variable "vnet_name" {
  type = string
}

variable "vnet_rg" {
  type = string
}

variable "subnet_name" {
  type = string
}
