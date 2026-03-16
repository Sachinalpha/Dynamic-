provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

# Get current client configuration for access policies
data "azurerm_client_config" "current" {}

# Get existing resource group
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

locals {
  common_tags = merge(var.tags, {
    ManagedBy = "Terraform"
    Purpose   = "KeyVault-Migration"
  })
}

# --------------------------------------------
# Source Key Vault
# --------------------------------------------
resource "azurerm_key_vault" "source" {
  name                          = var.source_keyvault_name
  location                      = var.location != "" ? var.location : data.azurerm_resource_group.rg.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  tenant_id                     = var.tenant_id
  sku_name                      = var.sku_name
  soft_delete_retention_days    = var.soft_delete_retention_days
  purge_protection_enabled      = var.purge_protection_enabled
  enable_rbac_authorization     = var.enable_rbac_authorization
  enabled_for_deployment        = true
  enabled_for_disk_encryption   = true
  enabled_for_template_deployment = true

  network_acls {
    default_action             = var.network_acls_default_action
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.allowed_ip_ranges
  }

  # Access policy for the service principal running Terraform
  dynamic "access_policy" {
    for_each = var.enable_rbac_authorization ? [] : [1]
    content {
      tenant_id = var.tenant_id
      object_id = data.azurerm_client_config.current.object_id

      secret_permissions = [
        "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
      ]
      key_permissions = [
        "Get", "List", "Create", "Delete", "Update", "Recover", "Backup", "Restore",
        "Import", "Purge", "Encrypt", "Decrypt", "Sign", "Verify", "WrapKey", "UnwrapKey"
      ]
      certificate_permissions = [
        "Get", "List", "Create", "Delete", "Update", "Recover", "Backup", "Restore",
        "Import", "Purge", "ManageContacts", "ManageIssuers", "GetIssuers", "ListIssuers"
      ]
    }
  }

  tags = local.common_tags
}

# --------------------------------------------
# Target Key Vault
# --------------------------------------------
resource "azurerm_key_vault" "target" {
  name                          = var.target_keyvault_name
  location                      = var.location != "" ? var.location : data.azurerm_resource_group.rg.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  tenant_id                     = var.tenant_id
  sku_name                      = var.sku_name
  soft_delete_retention_days    = var.soft_delete_retention_days
  purge_protection_enabled      = var.purge_protection_enabled
  enable_rbac_authorization     = var.enable_rbac_authorization
  enabled_for_deployment        = true
  enabled_for_disk_encryption   = true
  enabled_for_template_deployment = true

  network_acls {
    default_action             = var.network_acls_default_action
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.allowed_ip_ranges
  }

  # Access policy for the service principal running Terraform
  dynamic "access_policy" {
    for_each = var.enable_rbac_authorization ? [] : [1]
    content {
      tenant_id = var.tenant_id
      object_id = data.azurerm_client_config.current.object_id

      secret_permissions = [
        "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
      ]
      key_permissions = [
        "Get", "List", "Create", "Delete", "Update", "Recover", "Backup", "Restore",
        "Import", "Purge", "Encrypt", "Decrypt", "Sign", "Verify", "WrapKey", "UnwrapKey"
      ]
      certificate_permissions = [
        "Get", "List", "Create", "Delete", "Update", "Recover", "Backup", "Restore",
        "Import", "Purge", "ManageContacts", "ManageIssuers", "GetIssuers", "ListIssuers"
      ]
    }
  }

  tags = local.common_tags
}
