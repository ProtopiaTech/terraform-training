# Lab 06 — Storage Account, Private Endpoint i zależności

## Cel

Utworzyć Storage Account dostępny wyłącznie przez Private Endpoint w podsieci z Lab-03, i zrozumieć różnicę między zależnością **niejawną** a **jawną** (`depends_on`) — łącznie z tym, kiedy `depends_on` jest właściwym narzędziem, a kiedy jest obejściem, którego lepiej unikać.

Czas trwania: 60 minut.

Kontynuujemy pracę w `../workshop/`.

## Wstęp

Terraform buduje graf zależności na podstawie **odwołań** w kodzie: jeśli zasób A używa `atrybutu` zasobu B (np. `azurerm_subnet.private_endpoints.id`), Terraform wie, że musi najpierw utworzyć B. To jest zależność **niejawna** — najczęstszy i preferowany przypadek, bo wynika wprost z kodu, i to jej powinieneś/aś szukać w pierwszej kolejności, projektując zasoby.

`depends_on` istnieje na sytuacje, w których zależność jest realna, ale nie da się jej wyrazić przez żadne odwołanie do atrybutu. Takie przypadki są w praktyce **rzadkie** — jeśli sięgasz po `depends_on`, to często sygnał, że da się to samo osiągnąć czystszym odwołaniem (np. dodając `network_rules` ze wskazaniem na podsieć, zamiast pisać "ta sieć musi istnieć wcześniej" słownie w komentarzu). W tym labie pokażemy `depends_on` na przykładzie, który jest celowo sztuczny — żebyś zobaczył(a) mechanikę — i wprost powiemy, gdzie jest granica.

Storage Account, który dziś utworzymy, musi mieć globalnie unikalną nazwę w całym Azure — użyjemy do tego `local.name_prefix_alnum` z Laba 03/04, więc nic nowego nie musisz tu wymyślać.

## Krok 1 — Wygeneruj nazwę Storage Account

Dopisz do `locals.tf`:

```hcl
locals {
  name_prefix = "${var.project}-${var.owner}"

  name_prefix_alnum = lower(replace(local.name_prefix, "/[^a-zA-Z0-9]/", ""))

  common_tags = {
    owner       = var.owner
    environment = var.environment
    gdpr        = var.gdpr
    managed_by  = "terraform"
  }

  # Storage Account ma twardy limit Azure: 3-24 znaki, tylko małe litery i cyfry.
  # To ograniczenie zasobu, nie nasz wybór stylistyczny — substr()/lower() są
  # tu na wypadek, gdyby projekt/owner kiedyś się wydłużyły (np. zmieni się
  # walidacja w variables.tf) i suma przekroczyła limit. Bez tego dowiedzielibyśmy
  # się o przekroczeniu dopiero z błędu Azure przy apply, a nie wcześniej.
  storage_account_name = substr(lower("st${local.name_prefix_alnum}"), 0, 24)
}
```

Storage Account akceptuje tylko małe litery i cyfry, 3–24 znaki — dlatego reużywamy `name_prefix_alnum`, a nie `name_prefix` (który ma myślniki). `lower()` gwarantuje małe litery niezależnie od tego, co trafi do `name_prefix_alnum` w przyszłości, a `substr(..., 0, 24)` obcina wynik do 24 znaków, gdyby kiedykolwiek okazał się dłuższy — dziś, przy obecnych limitach `project` (2-8 znaków) i `owner` (2-6 znaków) z Laba 02, `"st" + name_prefix_alnum` nigdy nie przekracza ~16 znaków, więc `substr()` nic nie obcina. To celowe zabezpieczenie na przyszłość, nie obejście istniejącego problemu — dopisujemy je tu, bo to jest twarde ograniczenie zasobu w Azure, a nie coś, co możemy negocjować.

## Krok 2 — Utwórz Storage Account (bez publicznego dostępu)

Stwórz plik `storage.tf`:

```bash
touch storage.tf
```

```hcl
resource "azurerm_storage_account" "main" {
  name                = local.storage_account_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access = "Disabled"

  tags = local.common_tags

  # Zależność jawna, CELOWO SZTUCZNA na potrzeby ćwiczenia: żaden atrybut
  # poniżej nie odwołuje się do VNet, więc Terraform nie miałby żadnego
  # powodu, żeby czekać na sieć. Udajemy, że firmowa polityka wymaga tej
  # kolejności. W realnym kodzie: jeśli to możliwe, wolej przerobić kod tak,
  # żeby zależność była niejawna (patrz Zadanie dodatkowe), zamiast zgadywać
  # przez depends_on.
  depends_on = [azurerm_virtual_network.main]
}
```

`public_network_access = "Disabled"` wyłącza dostęp przez publiczny internet — jedyną drogą do tego konta będzie Private Endpoint.

## Krok 3 — Podłącz Private Endpoint

```hcl
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
```

Zwróć uwagę: `subnet_id` i `private_connection_resource_id` to odwołania do atrybutów innych zasobów — to są zależności **niejawne**. Nie musisz dopisywać `depends_on` dla VNetu ani Storage Account w tym zasobie — Terraform już wie o kolejności.

Zwróć też uwagę na typy: `subresource_names = ["blob"]` to `list(string)` (z Laba 04) — nawet z jednym elementem, wciąż lista, nie sam string. `tags = local.common_tags` to z kolei `map(string)` — para klucz/wartość, gdzie oba są tekstem. Gdybyś chciał(a) otagować liczbą (np. `retencja = 30`), musiałbyś/abyś zamienić ją na tekst (`"30"`) — mapa tagów w Azure to zawsze `map(string)`, bez wyjątków.

**Uczciwe zastrzeżenie:** to, co tu tworzymy, nie ma jeszcze podłączonej strefy Private DNS (`privatelink.blob.core.windows.net`). Bez niej nazwa `*.blob.core.windows.net` nie rozwiąże się na prywatny adres IP z poziomu VNet — działa sam adres IP endpointu, ale nie automatyczne rozpoznawanie nazwy. W tym kursie nie mamy maszyny wewnątrz sieci, żeby to przetestować end-to-end (żadny lab nie tworzy VM) — Zadanie dodatkowe pokazuje, jak dopiąć DNS, a zweryfikujesz to przez konfigurację (`private_dns_zone_configs` w outpucie), nie przez realny ruch sieciowy.

## Krok 4 — Dodaj outputy

```hcl
output "storage_account_id" {
  value = azurerm_storage_account.main.id
}

output "private_endpoint_ip" {
  value = azurerm_private_endpoint.storage.private_service_connection[0].private_ip_address
}
```

## Krok 5 — Zaplanuj i zaaplikuj

```bash
terraform validate
terraform plan
terraform apply
```

## Pytania kontrolne

- Co by się stało, gdybyś usunął(a) `depends_on` z `azurerm_storage_account.main`? Czy `terraform apply` na pewno zawsze utworzyłby VNet przed storage? (Podpowiedź: w tym konkretnym, małym grafie zależności — sprawdź empirycznie, usuwając `depends_on` i patrząc na `terraform plan` — czy widzisz tam cokolwiek, co by to gwarantowało?)
- Dlaczego `azurerm_private_endpoint.storage` NIE potrzebuje jawnego `depends_on` na `azurerm_storage_account.main`, mimo że logicznie storage musi istnieć wcześniej?
- Gdybyś miał(a) do wyboru: dodać `depends_on`, czy przeprojektować kod tak, żeby zależność była niejawna — od czego zależy Twój wybór?

## Zadanie dodatkowe

Dwie rzeczy do zrobienia, niezależnie od siebie:

1. **Zamień sztuczny `depends_on` na prawdziwą zależność niejawną.** Dodaj do `azurerm_storage_account.main` blok `network_rules` wskazujący `virtual_network_subnet_ids = [azurerm_subnet.private_endpoints.id]` (i `default_action = "Deny"`) — teraz storage account naprawdę odwołuje się do podsieci, więc `depends_on` na VNet staje się zbędny (VNet i tak musi powstać, bo podsieć od niego zależy). Usuń `depends_on` i sprawdź w `terraform plan`, że kolejność wciąż jest poprawna.
2. Dodaj `azurerm_private_dns_zone` (`privatelink.blob.core.windows.net`) + `azurerm_private_dns_zone_virtual_network_link` + blok `private_dns_zone_group` w `azurerm_private_endpoint.storage`. Dodaj output pokazujący `azurerm_private_endpoint.storage.private_dns_zone_configs` i sprawdź, że po `apply` nie jest pusty — to Twój dowód, że DNS jest spięty, nawet bez maszyny do testowania resolucji.

## Dokumentacja

- [Meta-argument `depends_on` (zależności jawne)](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on)
- [Funkcja `substr()`](https://developer.hashicorp.com/terraform/language/functions/substr)
- [Zasób `azurerm_storage_account`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account)
- [Zasób `azurerm_private_endpoint`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint)
