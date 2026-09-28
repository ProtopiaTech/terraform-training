output "user_principal_name" {
  value = azuread_user.this.user_principal_name
}

# Celowo odsłonięte przez nonsensitive(): to jednorazowy wydruk poświadczeń
# startowych, nie sekret zarządzany w czasie. Bez tego Terraform ukrywałby
# hasło w każdym plan/apply, bo pochodzi ono z random_password (provider
# oznacza jego result jako sensitive, i ta cecha propaguje się dalej).
output "password" {
  value = nonsensitive(azuread_user.this.password)
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "object_id" {
  value = azuread_user.this.object_id
}
