resource "azurerm_key_vault" "kv" {
  name                        = var.keyvault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = "premium"

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"       # Required
    virtual_network_subnet_ids = [var.subnet_id]
  }
}
