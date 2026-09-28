locals {
  name_prefix = "${var.project}-${var.owner}"

  name_prefix_alnum = lower(replace(local.name_prefix, "/[^a-zA-Z0-9]/", ""))

  common_tags = {
    owner       = var.owner
    environment = var.environment
    gdpr        = var.gdpr
    managed_by  = "terraform"
  }

  vnet_tags = var.is_temporary ? merge(local.common_tags, { ttl = "auto-cleanup" }) : local.common_tags

  # Storage Account ma twardy limit Azure: 3-24 znaki, tylko małe litery i cyfry.
  # substr()/lower() to zabezpieczenie na przyszłość, gdyby project/owner
  # kiedyś się wydłużyły — patrz README Laba 06.
  storage_account_name = substr(lower("st${local.name_prefix_alnum}"), 0, 24)
  key_vault_name       = "kv-${local.name_prefix}"
}
