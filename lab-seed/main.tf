data "azuread_client_config" "current" {}

# Wspólna grupa dla wszystkich uczestników tego batcha. Zarządzamy członkostwem
# przez osobne zasoby azuread_group_member (nie przez inline `members` na
# azuread_group) — inline `members` stworzyłoby cykl: grupa potrzebowałaby
# object_id użytkowników, a użytkownicy (w module) potrzebują object_id grupy
# do przypisania roli Reader na swoim RG.
resource "azuread_group" "trainees" {
  display_name     = var.group_name
  security_enabled = true
  owners           = [data.azuread_client_config.current.object_id]
}

# Jeden losowy sufiks na cały batch — odróżnia loginy z tego uruchomienia od
# loginów z innych/wcześniejszych przebiegów tego samego narzędzia w tej samej
# subskrypcji. Raz wylosowany, zostaje w stanie — kolejne "apply" (np. po
# zwiększeniu trainee_count) nie zmienia już istniejących loginów.
resource "random_string" "batch" {
  length  = 4
  upper   = false
  special = false
}

module "trainee" {
  source = "./modules/trainee"

  for_each = { for n in range(1, var.trainee_count + 1) : tostring(n) => n }

  counter         = each.value
  batch_suffix    = random_string.batch.result
  tenant_domain   = var.tenant_domain
  location        = var.location
  group_object_id = azuread_group.trainees.object_id
}

resource "azuread_group_member" "trainees" {
  for_each = module.trainee

  group_object_id  = azuread_group.trainees.object_id
  member_object_id = each.value.object_id
}
