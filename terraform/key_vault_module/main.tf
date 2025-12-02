# --------------------------------------------
# Random number for uniqueness
# --------------------------------------------
resource "random_integer" "kv_rand" {
  min = 100
  max = 999
}

# --------------------------------------------
# Generate Key Vault Name (first 3 segments, max 9 chars each)
# --------------------------------------------
locals {
  # Split RG name by hyphen
  segments = split("-", var.resource_group_name)
  n-name = slice(local.segments, 0, 4)

  # Trim each segment to max 9 characters
  trimmed_segments = [for s in local.n-name : substr(s, 0, 9)]

  # Join all segments without hyphens
  kv_base = join("", local.trimmed_segments)

  # Final Key Vault name: lowercase + 3-digit random + "key"
  kv_final_name = lower("${local.kv_base}${random_integer.kv_rand.result}key")
}

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
  name                = local.kv_final_name
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

