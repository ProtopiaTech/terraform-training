# Lab 03 — Sieć wirtualna i podsieci

## Cel

Ustalić konwencję nazewnictwa zasobów przez `local`, i utworzyć pierwszy prawdziwy zasób w Azure: sieć wirtualną (VNet) z dwiema podsieciami o różnym przeznaczeniu.

Czas trwania: 60 minut.

Kontynuujemy pracę w `../workshop/`.

## Wstęp

Zanim utworzymy cokolwiek, ustalimy wspólną nazwę bazową dla wszystkich zasobów w tym kursie, zbudowaną z `var.project` i `var.owner` (dodanych w Labie 02). Dzięki temu żadna nazwa zasobu nie jest wpisana na sztywno — wynika z Twoich zmiennych, więc automatycznie jest unikalna między uczestnikami i między kolejnymi podejściami do kursu.

Będziemy tworzyć:

- **VNet** — `10.20.0.0/16`,
- **Podsieć pod Private Endpointy** (użyjemy jej w Labie 06, do prywatnego dostępu do Storage Account),
- **Podsieć z delegacją dla Web App** — delegacja pozwala usłudze platformowej (tu: Azure App Service) "przejąć" zarządzanie podsiecią.

Terraform udostępnia dwa sposoby definiowania podsieci: inline (wewnątrz `azurerm_virtual_network`) albo jako osobny zasób `azurerm_subnet`. Nie można mieszać obu podejść na tym samym VNet-cie. Użyjemy osobnych zasobów `azurerm_subnet` — łatwiej wtedy odwoływać się do konkretnej podsieci po `id` (przyda się w kolejnych labach).

## Krok 1 — Ustal konwencję nazewnictwa

Stwórz plik `locals.tf`:

```bash
touch locals.tf
```

```hcl
locals {
  name_prefix = "${var.project}-${var.owner}"

  # Wersja bez myślników/wielkich liter — potrzebna dla zasobów takich jak
  # Storage Account, które akceptują tylko małe litery i cyfry (Lab 06, 07).
  name_prefix_alnum = lower(replace(local.name_prefix, "/[^a-zA-Z0-9]/", ""))
}
```

`local` to nazwana wartość policzona raz w kodzie na podstawie zmiennych — w przeciwieństwie do `variable`, nie ustawia się jej z zewnątrz, tylko wylicza wewnątrz konfiguracji. Od teraz każdy zasób w tym kursie dostanie nazwę zbudowaną z `local.name_prefix`.

## Krok 2 — Utwórz sieć wirtualną

Stwórz plik `network.tf`:

```bash
touch network.tf
```

```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}"
  address_space       = ["10.20.0.0/16"]
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
}
```

Zwróć uwagę: `location` i `resource_group_name` pochodzą z `data.azurerm_resource_group.main`, który dodałeś/aś w Labie 02 — to jest **niejawna zależność** (Terraform sam wie, że musi najpierw odczytać grupę zasobów).

Zwróć też uwagę na `address_space = ["10.20.0.0/16"]` — kwadratowe nawiasy oznaczają **listę** (typ `list(string)`), nawet z jednym elementem. To pierwsze zetknięcie z typem kolekcji w tym kursie — szerszy przegląd typów zmiennych (i jak je walidować) jest w Labie 04.

## Krok 3 — Dodaj podsieć pod Private Endpoint

Dopisz do `network.tf`:

```hcl
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-pe-${local.name_prefix}"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.1.0/24"]

  private_endpoint_network_policies = "Disabled"
}
```

Uwaga na `private_endpoint_network_policies`: `Disabled` to akurat wartość **domyślna** tego pola w obecnej wersji providera — gdybyśmy jej w ogóle nie wpisali, i tak by taka była. Wpisujemy ją tu jawnie nie dlatego, że inaczej coś by się zepsuło, tylko żeby kod sam dokumentował intencję ("ta podsieć jest świadomie pod private endpointy") — nie zgadujesz, patrząc na provider docs, tylko widzisz to wprost w kodzie. To ważne rozróżnienie: jawne ustawienie wartości domyślnej jest dobrą praktyką czytelności, ale nie myl tego z "to pole jest wymagane, żeby cokolwiek zadziałało".

## Krok 4 — Dodaj podsieć z delegacją dla Web App

```hcl
resource "azurerm_subnet" "webapp_delegated" {
  name                 = "snet-web-${local.name_prefix}"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.2.0/24"]

  delegation {
    name = "webapp-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}
```

Delegacja mówi Azure: "tę podsieć może zarządzać App Service Plan, jeśli go tu podłączysz". Bez delegacji Web App nie może się zintegrować z tą siecią. To pole faktycznie zmienia zachowanie (w odróżnieniu od kroku 3) — bez niego delegacja w ogóle by nie istniała.

## Krok 5 — Dodaj outputy

Dopisz do `outputs.tf`:

```hcl
output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "subnet_private_endpoints_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "subnet_webapp_id" {
  value = azurerm_subnet.webapp_delegated.id
}
```

## Krok 6 — Zaplanuj i zaaplikuj

```bash
terraform validate
terraform plan
```

Przeczytaj plan — ile zasobów przybędzie? Sprawdź, że nazwa VNet w planie zawiera Twój `project` i `owner`, a nie sztywny tekst.

```bash
terraform apply
```

Sprawdź w Azure Portalu, że VNet i obie podsieci istnieją, z poprawną konfiguracją i nazwami zawierającymi Twój prefiks.

## Pytania kontrolne

- Co by się stało, gdybyś spróbował(a) zdefiniować te same podsieci inline w `azurerm_virtual_network` *oraz* jako osobne zasoby `azurerm_subnet`?
- Dlaczego jawne wpisanie wartości domyślnej (`private_endpoint_network_policies = "Disabled"`) bywa dobrą praktyką, mimo że nie zmienia zachowania zasobu?
- Gdyby dwie osoby w tym kursie miały ten sam `owner`, ale różny `project`, czy nazwy zasobów by się zderzyły?

## Zadanie dodatkowe

Dodaj trzecią podsieć `snet-mgmt-${local.name_prefix}` (`10.20.3.0/24`), bez delegacji i bez specjalnej konfiguracji. Zastanów się, do czego mogłaby służyć w prawdziwym środowisku (np. jump host, bastion). Jeśli w kolejnym labie zaczniesz od `solution/` zamiast od własnego kodu, ta podsieć zniknie — `solution/` zawiera tylko obowiązkowy zakres, nie zadania dodatkowe.

## Dokumentacja

- [Wartości lokalne (`locals`)](https://developer.hashicorp.com/terraform/language/values/locals)
- [Funkcja `replace()`](https://developer.hashicorp.com/terraform/language/functions/replace)
- [Funkcja `lower()`](https://developer.hashicorp.com/terraform/language/functions/lower)
- [Zasób `azurerm_virtual_network`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network)
- [Zasób `azurerm_subnet`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet)
