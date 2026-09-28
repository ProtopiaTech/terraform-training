locals {
  name_prefix = "${var.project}-${var.owner}"

  # Wersja bez myślników/wielkich liter — potrzebna dla zasobów takich jak
  # Storage Account, które akceptują tylko małe litery i cyfry (Lab 06, 07).
  name_prefix_alnum = lower(replace(local.name_prefix, "/[^a-zA-Z0-9]/", ""))
}
