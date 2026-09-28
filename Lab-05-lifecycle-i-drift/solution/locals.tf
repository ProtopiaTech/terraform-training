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
}
