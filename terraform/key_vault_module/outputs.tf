output "keyvault_id" {
  value = azurerm_key_vault.kv.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "subnet_id_used" {
  value = data.azurerm_subnet.subnet   #check
}

output "vnet_id_used" {
  value = data.azurerm_vnet.vnet   #check
}
