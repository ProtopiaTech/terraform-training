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
