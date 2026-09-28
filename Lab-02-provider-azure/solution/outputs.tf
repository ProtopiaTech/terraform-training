output "greeting_path" {
  description = "Ścieżka do wygenerowanego pliku powitania."
  value       = local_file.greeting.filename
}

output "resource_group_location" {
  description = "Lokalizacja (region) grupy zasobów."
  value       = data.azurerm_resource_group.main.location
}
