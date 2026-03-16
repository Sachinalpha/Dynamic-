# --------------------------------------------
# Source Key Vault Outputs
# --------------------------------------------
output "source_keyvault_id" {
  description = "Resource ID of the source Key Vault"
  value       = azurerm_key_vault.source.id
}

output "source_keyvault_name" {
  description = "Name of the source Key Vault"
  value       = azurerm_key_vault.source.name
}

output "source_keyvault_uri" {
  description = "URI of the source Key Vault"
  value       = azurerm_key_vault.source.vault_uri
}

# --------------------------------------------
# Target Key Vault Outputs
# --------------------------------------------
output "target_keyvault_id" {
  description = "Resource ID of the target Key Vault"
  value       = azurerm_key_vault.target.id
}

output "target_keyvault_name" {
  description = "Name of the target Key Vault"
  value       = azurerm_key_vault.target.name
}

output "target_keyvault_uri" {
  description = "URI of the target Key Vault"
  value       = azurerm_key_vault.target.vault_uri
}

# --------------------------------------------
# Common Outputs
# --------------------------------------------
output "resource_group_name" {
  description = "Resource group containing the Key Vaults"
  value       = data.azurerm_resource_group.rg.name
}

output "location" {
  description = "Azure region of the Key Vaults"
  value       = azurerm_key_vault.source.location
}
