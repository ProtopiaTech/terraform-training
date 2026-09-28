output "greeting_path" {
  description = "Ścieżka do wygenerowanego pliku powitania."
  value       = local_file.greeting.filename
}

output "resource_group_location" {
  description = "Lokalizacja (region) grupy zasobów."
  value       = data.azurerm_resource_group.main.location
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_private_endpoints_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "subnet_webapp_id" {
  value = azurerm_subnet.webapp_delegated.id
}

output "storage_account_id" {
  value = azurerm_storage_account.main.id
}

output "private_endpoint_ip" {
  value = azurerm_private_endpoint.storage.private_service_connection[0].private_ip_address
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}
