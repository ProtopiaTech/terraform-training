module "reports_storage" {
  source = "./modules/storage"

  resource_group_name        = data.azurerm_resource_group.main.name
  name_prefixx               = "${local.name_prefix}-reports"
  tags                       = local.common_tags
  private_endpoint_subnet_id = azurerm_subnet.webapp_delegated.id
}
