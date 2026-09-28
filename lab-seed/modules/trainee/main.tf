locals {
  # Konwencja loginu należy do modułu, nie do roota — patrz Lab 09 (moduły),
  # ta sama zasada: moduł sam wie, jak zbudować poprawną nazwę tego, czym zarządza.
  username = "user${var.batch_suffix}-${var.counter}"
}

resource "random_password" "this" {
  length      = 20
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

resource "azuread_user" "this" {
  user_principal_name = "${local.username}@${var.tenant_domain}"
  display_name        = "Uczestnik ${local.username}"
  mail_nickname       = local.username
  password            = random_password.this.result

  disable_password_expiration = true
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.username}"
  location = var.location
}

resource "azurerm_role_assignment" "owner" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Owner"
  principal_id         = azuread_user.this.object_id
}

# Grupa wszystkich uczestników dostaje Reader na TEJ grupie zasobów — dzięki
# temu każdy uczestnik widzi listę/zawartość RG innych uczestników (bo należy
# do grupy), ale nie ma żadnych uprawnień poza tymi konkretnymi RG w subskrypcji.
resource "azurerm_role_assignment" "group_reader" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Reader"
  principal_id         = var.group_object_id
}
