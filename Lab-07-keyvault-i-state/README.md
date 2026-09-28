# Lab 07 — Key Vault, RBAC i plik stanu

## Cel

Utworzyć Key Vault z autoryzacją przez RBAC, nadać sobie uprawnienie do zarządzania sekretami, i zobaczyć, dlaczego plik stanu Terraform trzeba traktować jak dane wrażliwe.

Czas trwania: 75 minut.

Kontynuujemy pracę w `../workshop/`. To najdłuższy lab — zawiera świadomy dwuetapowy `apply`, bo nadanie roli RBAC w Azure potrzebuje chwili na propagację.

## Wstęp

Key Vault może autoryzować dostęp na dwa sposoby: starym mechanizmem *Access Policies* albo przez *Azure RBAC* (zalecane obecnie podejście). Użyjemy RBAC: nadamy sobie rolę **Key Vault Secrets Officer** przez `azurerm_role_assignment`, tak samo jak nadawałoby się dowolną inną rolę w Azure.

Problem: rola RBAC potrzebuje zwykle od kilkudziesięciu sekund do kilku minut, żeby się w pełni propagować — **to opóźnienie jest po stronie Azure, nie Terraforma, i żaden `depends_on` go nie przyspieszy ani nie odczeka**. `depends_on` (którego użyjemy niżej) gwarantuje tylko, że Terraform wywoła API tworzenia roli PRZED API tworzenia sekretu — nie gwarantuje, że w momencie drugiego wywołania rola już się w pełni rozpropagowała. Dlatego realnym rozwiązaniem tego problemu jest rozbicie pracy na dwa kroki z ręcznym odczekaniem między nimi, a `depends_on` to tylko poprawna kolejność wywołań, nie mechanizm czekania.

## Krok 1 — Dodaj provider `random`

W `versions.tf` dopisz w `required_providers`:

```hcl
random = {
  source  = "hashicorp/random"
  version = "~> 3.6"
}
```

## Krok 2 — Rozszerz konfigurację providera Azure

W `providers.tf` dodaj blok `features.key_vault`, żeby ułatwić sobie wielokrotne tworzenie/niszczenie vaulta w trakcie ćwiczeń:

```hcl
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  subscription_id = var.subscription_id
}
```

## Krok 3 — Odczytaj dane bieżącego użytkownika/aplikacji

Stwórz plik `keyvault.tf`:

```bash
touch keyvault.tf
```

```hcl
data "azurerm_client_config" "current" {}
```

`data.azurerm_client_config.current` sam w sobie jest wartością typu `object` — ma kilka pól (`tenant_id`, `object_id`, `subscription_id`, `client_id`), do których sięgasz przez kropkę, tak jak w przykładzie `object({...})` z Laba 04. Nie musisz nigdzie deklarować tego typu — providery same definiują kształt tego, co zwracają `data`/`resource`, a Ty go tylko odczytujesz.

Dopisz do `locals.tf` nazwę Key Vaulta, tą samą konwencją co dotychczas (Key Vault dopuszcza myślniki, więc używamy `name_prefix`, nie `name_prefix_alnum`):

```hcl
key_vault_name = "kv-${local.name_prefix}"
```

## Krok 4 — Utwórz Key Vault i rolę (pierwszy `apply`)

Dopisz do `keyvault.tf`:

```hcl
resource "azurerm_key_vault" "main" {
  name                       = local.key_vault_name
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7

  tags = local.common_tags
}

resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
```

Dopisz też do `outputs.tf`:

```hcl
output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}
```

```bash
terraform validate
terraform plan
terraform apply
```

**Zatrzymaj się tutaj.** Nie dodawaj jeszcze sekretu.

## Krok 5 — Poczekaj na propagację RBAC

Odczekaj 1–2 minuty (dobry moment na pytania kontrolne poniżej albo przerwę). W tym czasie możesz sprawdzić w Portalu: Key Vault → Access control (IAM) → Role assignments — powinna tam już być widoczna Twoja rola.

## Krok 6 — Dodaj sekret (drugi `apply`)

Dopisz do `keyvault.tf`:

```hcl
resource "random_password" "app" {
  length  = 24
  special = true
}

resource "azurerm_key_vault_secret" "app_password" {
  name         = "app-password"
  value        = random_password.app.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.kv_secrets_officer]
}
```

`depends_on` tutaj zapewnia tylko, że Terraform wywoła API tworzenia sekretu dopiero PO API tworzenia roli — to konieczne, bo `key_vault_id` samo w sobie nie odwołuje się do roli, więc bez `depends_on` Terraform mógłby (choć nie musi) spróbować utworzyć oba równolegle. Właściwą ochroną przed błędem propagacji jest jednak przerwa z Kroku 5, nie ten `depends_on`.

```bash
terraform plan
terraform apply
```

Jeśli dostaniesz błąd `403 Forbidden`, odczekaj chwilę dłużej i uruchom `terraform apply` ponownie — nic się nie popsuło, to tylko propagacja RBAC.

## Krok 7 — Zajrzyj do stanu

```bash
terraform state show azurerm_key_vault_secret.app_password
```

Pole `value` pokaże `(sensitive value)`, nie samo hasło. Od kilku wersji Terraform świadomie maskuje w terminalu wartości, które provider oznaczył jako `sensitive` — żeby nie wyciekały przez przypadek do historii terminala czy nagrania ekranu.

**To maskowanie jest kosmetyczne, nie realne.** Sam plik stanu na dysku nie wie nic o "sensitive" — przechowuje wszystko jawnie. Zobacz to bezpośrednio:

```bash
terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="azurerm_key_vault_secret") | .values.value'
```

Tym razem zobaczysz **wartość hasła w czystym tekście**. To samo znajdziesz, otwierając wprost `terraform.tfstate` — CLI maskuje tylko to, co Ci *wyświetla*, nie to, co zapisuje na dysku.

To jest kluczowa lekcja o pliku stanu — i o tym, że maskowanie w terminalu daje fałszywe poczucie bezpieczeństwa, jeśli nie rozumiesz tej różnicy:

**Zalety stanu:**
- jedyne źródło prawdy o tym, co Terraform zarządza i w jakiej wersji,
- pozwala liczyć różnice (`plan`) bez odpytywania całego Azure za każdym razem,
- śledzi zależności między zasobami.

**Wady/ryzyka stanu:**
- zawiera wszystkie atrybuty zasobów **w plaintext**, łącznie z sekretami jak wyżej,
- lokalny plik = pojedynczy punkt awarii i brak współdzielenia w zespole,
- wymaga takiej samej ochrony jak najbardziej wrażliwe dane w organizacji (uprawnienia, szyfrowanie, backup).

W Labie 08 przeniesiemy ten stan do backendu zdalnego — to pierwszy krok do bezpieczniejszego zarządzania nim.

## Pytania kontrolne

- Dlaczego `azurerm_key_vault_secret.app_password` ma jawny `depends_on`, skoro już odwołuje się do `azurerm_key_vault.main.id`? Dlaczego ten `depends_on` NIE rozwiązuje problemu propagacji RBAC, mimo że dotyczy właśnie roli?
- Kto w Twojej organizacji powinien mieć dostęp do odczytu pliku `terraform.tfstate`?

## Zadanie dodatkowe

Zanim zaczniesz: **to zadanie nie jest tak proste, jak "zrób to samo co w Labie 06"**, i to jest właśnie jego lekcja.

### Dlaczego zwykłe zablokowanie dostępu publicznego tu nie zadziała

Key Vault ma dwie oddzielne płaszczyzny:

- **Control plane** (tworzenie/usuwanie vaulta, `azurerm_role_assignment`) — idzie przez Azure Resource Manager, niezależnie od ustawień sieciowych vaulta.
- **Data plane** (sekrety, klucze, certyfikaty — czyli dokładnie to, czym zarządza `azurerm_key_vault_secret`) — idzie bezpośrednio do endpointu samego vaulta (`https://<vault>.vault.azure.net`).

Storage Account w Labie 06 nigdy nie dotknął tego problemu, bo ten lab zarządza tylko samym kontem (control plane) — nie wrzuca do niego żadnego bloba (data plane). Tutaj jest inaczej: `azurerm_key_vault_secret.app_password` to zawsze operacja na data plane. Jeśli ustawisz `public_network_access_enabled = false` i zostawisz tylko Private Endpoint, Twój `terraform apply` (uruchamiany z laptopa albo z Cloud Shell — **nie** z wnętrza VNet-u) przestanie mieć dostęp do sekretów i zacznie failować na samym `apply`, nie na uprawnieniach — na samym połączeniu.

### Co zrobić zamiast tego

Zamiast blokować dostęp publiczny całkowicie, ogranicz go do adresu IP, z którego faktycznie odpalasz Terraform, przez `network_acls`:

```bash
# Twój aktualny publiczny adres IP
curl -s https://api.ipify.org
```

```hcl
resource "azurerm_key_vault" "main" {
  # ...bez zmian...

  public_network_access_enabled = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = ["<Twoje-publiczne-IP>/32"]
  }
}
```

Dodaj też Private Endpoint w podsieci `snet-pe-${local.name_prefix}` (tak jak w Labie 06) — to jest droga dostępu dla zasobów **wewnątrz** VNet (np. przyszłej aplikacji), a `network_acls` to droga dostępu dla **Ciebie i Terraforma z zewnątrz**. W realnym projekcie te dwie rzeczy działają równolegle: ruch z aplikacji w VNet idzie przez Private Endpoint, ruch operatora/CI z konkretnego IP (albo przez `network_acls.virtual_network_subnet_ids`, jeśli CI stoi w VNet) — przez allow-listę. Pełne zablokowanie (`default_action = "Deny"`, brak wyjątków) ma sens dopiero wtedy, gdy nikt spoza VNet-u nie musi już nigdy ręcznie zarządzać sekretami.

Sprawdź: `terraform plan` i `terraform apply` powinny nadal przechodzić z Twojego laptopa/Cloud Shell, mimo że dostęp publiczny nie jest już całkowicie otwarty.

### Pułapka nazewnictwa, na którą i tak warto zwrócić uwagę

Storage Account (Lab 06) używa `public_network_access = "Disabled"` (string). Key Vault używa innego atrybutu o innym typie: `public_network_access_enabled = false` (boolean). To nie literówka w tym kursie — to prawdziwa niespójność między dwoma zasobami providera `azurerm`, na którą natkniesz się i w realnych projektach. Sprawdź to sam(a) w dokumentacji providera, zanim zaczniesz pisać kod — nie kopiuj wzorca z `storage.tf` bez zastanowienia.

## Dokumentacja

- [Wartości wyjściowe — `sensitive`](https://developer.hashicorp.com/terraform/language/values/outputs)
- [Plik stanu — jak Terraform go używa](https://developer.hashicorp.com/terraform/language/state)
- [Zasób `azurerm_key_vault`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault)
- [Zasób `azurerm_role_assignment`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment)
- [Zasób `azurerm_key_vault_secret`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret)
- [Źródło danych `azurerm_client_config`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config)
- [Zasób `random_password`](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)
