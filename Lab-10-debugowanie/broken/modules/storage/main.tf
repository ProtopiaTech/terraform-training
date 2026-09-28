locals {
  # Storage Account: twardy limit Azure — 3-24 znaki, tylko małe litery i cyfry.
  # Moduł sam pilnuje własnej konwencji nazewnictwa, niezależnie od tego, co
  # dostał w name_prefix (ten sam wzorzec co w Labie 06, tu opakowany w moduł).
  storage_account_name = substr(lower(replace("st${var.name_prefix}", "/[^a-zA-Z0-9]/", "")), 0, 24)
}

resource "azurerm_storage_account" "this" {
  name                = local.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type

  public_network_access = "Disabled"

  tags = var.tags
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.name_prefix}"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  tags = var.tags
}
