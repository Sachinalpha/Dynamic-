provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

module "keyvault" {
  source               = "./key_vault_module"
  keyvault_name        = var.keyvault_name
  resource_group_name  = var.resource_group_name
  location             = var.location
  tenant_id            = var.tenant_id
  subnet_id            = var.subnet_id
}
