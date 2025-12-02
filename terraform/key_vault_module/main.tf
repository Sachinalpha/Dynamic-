# --------------------------------------------
# Look up VNet
# --------------------------------------------
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_rg
}

# --------------------------------------------
# Look up Subnet
# --------------------------------------------
data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.vnet_rg
}

# --------------------------------------------
# Key Vault
# --------------------------------------------
resource "azurerm_key_vault" "kv" {
  name                = var.keyvault_name
  location            = data.azurerm_virtual_network.vnet.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "premium"

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [data.azurerm_subnet.subnet.id]
  }
}

