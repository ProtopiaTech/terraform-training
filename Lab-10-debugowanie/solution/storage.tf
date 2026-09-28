resource "azurerm_storage_account" "main" {
  name                = local.storage_account_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access = "Disabled"

  tags = local.common_tags

  # Zależność jawna, celowo sztuczna na potrzeby ćwiczenia — patrz README.
  depends_on = [azurerm_virtual_network.main]
}

resource "azurerm_private_endpoint" "storage" {
  name                = "pe-storage-${local.name_prefix}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "psc-storage-${local.name_prefix}"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  tags = local.common_tags
}
