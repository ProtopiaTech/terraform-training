# Hasła są tu celowo odsłonięte (nonsensitive() w modules/trainee/outputs.tf) —
# to jednorazowy wydruk poświadczeń startowych dla prowadzącego, nie sekret,
# który ma zostać zamaskowany na stałe w terminalu.
output "credentials" {
  description = "Login, hasło startowe i grupa zasobów każdego uczestnika."
  value = {
    for idx, m in module.trainee : idx => {
      user_principal_name = m.user_principal_name
      password            = m.password
      resource_group_name = m.resource_group_name
    }
  }
}

output "group_object_id" {
  description = "Object ID grupy Entra ID wszystkich uczestników."
  value       = azuread_group.trainees.object_id
}
