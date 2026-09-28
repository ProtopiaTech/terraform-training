# Lab 04 — Zmienne, typy i tagi

## Cel

Poznać pełny zestaw typów zmiennych w Terraformie i sposoby ich walidacji, dodać zmienne `environment` i `gdpr`, i zbudować wspólny zestaw tagów przez `local`.

Czas trwania: 50 minut.

Kontynuujemy pracę w `../workshop/`.

## Wstęp

W Labie 02 dodałeś/aś `project` i `owner`, każdą z blokiem `validation`, bez pełnego wytłumaczenia. Teraz nadrabiamy: `validation` to warunek dołączony do zmiennej, sprawdzany **zanim** Terraform zrobi cokolwiek innego. Jeśli `condition` zwróci `false`, `terraform plan`/`apply` przerywa z Twoim `error_message`, zamiast próbować utworzyć zasób z nieprawidłową wartością i dostać niezrozumiały błąd z Azure dużo później (dokładnie to zademonstrowałeś/aś sam(a) w Labie 02, próbując `owner = "a"`).

### Typy zmiennych — pełny przegląd

Do tej pory każda Twoja zmienna miała `type = string`. To nie przypadek dla `owner`/`project`/`subscription_id` (nazwy i identyfikatory zawsze są tekstem, nawet jeśli wyglądają jak liczby albo kod — `subscription_id` to GUID, nie liczba), ale `string` to tylko jeden z kilku typów. Oto reszta:

**Prymitywne** (pojedyncza wartość):
```hcl
variable "przyklad_string" {
  type = string # tekst: "dev", "wg", "10.0.0.0/16"
}

variable "przyklad_number" {
  type = number # liczba, całkowita lub zmiennoprzecinkowa: 7, 3.14
}

variable "przyklad_bool" {
  type = bool # prawda/fałsz: true, false
}
```

**Kolekcje** (wiele wartości tego samego typu):
```hcl
variable "przyklad_list" {
  type = list(string) # uporządkowana lista: ["a", "b", "c"] — indeks ma znaczenie
}

variable "przyklad_set" {
  type = set(string) # zbiór bez powtórzeń i bez gwarantowanej kolejności
}

variable "przyklad_map" {
  type = map(string) # klucz → wartość: { dev = "10.0.0.0/24", prod = "10.1.0.0/24" }
}
```

Widziałeś/aś już `list(string)` w Labie 03 — `address_prefixes = ["10.20.1.0/24"]` to lista jednoelementowa — i `map(string)` w postaci `tags = { owner = ..., environment = ... }`.

**Strukturalne** (różne typy pól w jednej wartości):
```hcl
variable "przyklad_object" {
  type = object({
    name  = string
    count = number
    tags  = optional(map(string), {}) # optional() = pole nieobowiązkowe, z wartością domyślną
  })
}
```

Obiektów użyjesz naturalnie już za chwilę — bloki takie jak `network_acls { ... }` czy `security_rule { ... }` (Lab 09) to properties o strukturze bardzo zbliżonej do `object`.

**`any`** — rezygnacja z kontroli typu. Terraform przyjmie dosłownie wszystko. Unikaj, chyba że naprawdę nie wiesz z góry, jaki kształt będzie miała wartość (np. generyczny moduł) — tracisz przy tym najważniejszą korzyść z `type`: błąd przy złym typie **zanim** cokolwiek się wykona, zamiast w środku `apply`.

### `type` a `validation` — to nie to samo

- `type` sprawdza **kształt** danych: czy to na pewno tekst, liczba, lista stringów itd. Błąd typu zawsze wygląda podobnie: "invalid value for variable — string required".
- `validation` sprawdza **treść**, według reguł, które Ty definiujesz: czy tekst pasuje do wzorca, czy liczba mieści się w zakresie, czy wartość jest jedną z dozwolonych.

Obie kontrole działają zanim Terraform dotknie Azure. Poniżej masz trzy różne style walidacji, na trzech różnych typach:

```hcl
# regex — gdy wzorzec jest ważniejszy niż konkretna lista wartości (już znasz z owner/project)
validation {
  condition     = can(regex("^[a-z0-9]{2,6}$", var.owner))
  error_message = "owner: tylko małe litery i cyfry, 2-6 znaków."
}

# contains — gdy masz z góry znaną, skończoną listę dozwolonych wartości
validation {
  condition     = contains(["dev", "test", "staging", "prod"], var.environment)
  error_message = "environment musi być jednym z: dev, test, staging, prod."
}

# zakres liczbowy — dla type = number
variable "retention_days" {
  type    = number
  default = 30

  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 90
    error_message = "retention_days musi być liczbą od 1 do 90."
  }
}
```

## Krok 1 — Dodaj nowe zmienne

Dopisz do `variables.tf`:

```hcl
variable "environment" {
  description = "Środowisko: dev, test, staging lub prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "environment musi być jednym z: dev, test, staging, prod."
  }
}

variable "gdpr" {
  description = "Klasyfikacja RODO zasobu: public lub confidential."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "confidential"], var.gdpr)
    error_message = "gdpr musi być jednym z: public, confidential."
  }
}
```

Dodaliśmy `staging` do dozwolonych środowisk — typowy dodatkowy etap między `test` a `prod`, np. do testów wydajnościowych na konfiguracji zbliżonej do produkcyjnej.

## Krok 2 — Dodaj zmienną typu `bool`

Dopisz do `variables.tf` naszą pierwszą zmienną, która nie jest `string`:

```hcl
variable "is_temporary" {
  description = "Czy to wdrożenie jest tymczasowe (np. do testów) i powinno być oznaczone do automatycznego czyszczenia?"
  type        = bool
  default     = false
}
```

## Krok 3 — Złóż wspólne tagi w `local`

Dopisz do istniejącego `locals.tf` (nie twórz nowego pliku — masz go już z Laba 03):

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

  # Wyrażenie warunkowe: warunek ? wartość_gdy_true : wartość_gdy_false.
  # Pierwszy hands-on przykład użycia bool z Kroku 2.
  vnet_tags = var.is_temporary ? merge(local.common_tags, { ttl = "auto-cleanup" }) : local.common_tags
}
```

`merge(mapa1, mapa2)` łączy dwie mapy w jedną (druga nadpisuje klucze pierwszej przy konflikcie) — to ta sama funkcja, której użyjesz w Zadaniu dodatkowym.

## Krok 4 — Zastosuj tagi na VNet

W `network.tf` dopisz `tags = local.vnet_tags` do `azurerm_virtual_network.main` (świadomie **nie** `local.common_tags` — VNet dostaje wersję z ewentualnym `ttl`, reszta zasobów w kolejnych labach użyje `common_tags` wprost):

```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}"
  address_space       = ["10.20.0.0/16"]
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = local.vnet_tags
}
```

> Uwaga: `azurerm_subnet` (w tej wersji providera) nie obsługuje tagów — to normalne, nie każdy typ zasobu w Azure je wspiera.

## Krok 5 — Uzupełnij `terraform.tfvars`

Dopisz do swojego (niewersjonowanego) `terraform.tfvars`:

```hcl
environment = "dev"
gdpr        = "public"
```

`is_temporary` ma wartość domyślną (`false`) — nie musisz go dodawać do `tfvars`, chyba że chcesz ją nadpisać. Zaktualizuj też `terraform.tfvars.example`, żeby kolejni uczestnicy wiedzieli, czego się spodziewać (bez realnych wartości).

## Krok 6 — Zaplanuj i zaaplikuj

```bash
terraform validate
terraform plan
```

Terraform powinien zaproponować tylko **aktualizację** VNet (dodanie tagów), nie jego odtworzenie — bo `name` (jedyne pole, które wymusiłoby `-/+ replace`) w ogóle się nie zmienił. Sprawdź w planie, że tak jest (`~ update in-place`, nie `-/+ replace`).

```bash
terraform apply
```

Spróbuj chwilowo ustawić `environment = "staging"` — plan powinien przejść bez błędu walidacji (bo dodałeś tę wartość w Kroku 1). Teraz spróbuj `environment = "produkcja"` — zobacz błąd walidacji, dokładnie taki sam mechanizm jak przy `owner = "a"` w Labie 02. Wróć do poprawnej wartości.

Na koniec ustaw chwilowo `is_temporary = true` w `terraform.tfvars` i uruchom `terraform plan` — zobacz, że tag `ttl = "auto-cleanup"` pojawia się w planowanej zmianie na VNet, mimo że nigdzie nie napisałeś/aś `if`. Wróć do `false`.

## Pytania kontrolne

- Dlaczego `owner` (Lab 02) użył `regex`, `environment`/`gdpr` (ten lab) użyły `contains`, a przykładowy `retention_days` powyżej — porównania liczbowego? Od czego zależy, po który sposób sięgnąć?
- Co się różni między błędem `type` a błędem `validation`? Spróbuj (tylko w planie) podać `is_temporary = "tak"` zamiast `true` w `terraform.tfvars` i przeczytaj komunikat.
- Co się stanie z istniejącymi tagami na VNet, jeśli usuniesz `managed_by` z `local.common_tags` i zrobisz `apply`? Sprawdź to naprawdę, nie tylko w głowie.

## Zadanie dodatkowe

Dodaj czwartą zmienną `cost_center` z `validation`, że musi pasować do wzorca w stylu `CC-1234` (`can(regex("^CC-[0-9]{4}$", var.cost_center))`), i **rzeczywiście podłącz ją do tagów VNet** przez `merge()`, zamiast zostawić jako samą deklarację:

```hcl
tags = merge(local.vnet_tags, { cost_center = var.cost_center })
```

Osobno: spróbuj zapisać `variable "moje_srodowiska" { type = list(string) }` z domyślną wartością `["dev", "test"]`, i użyj `contains(var.moje_srodowiska, var.environment)` zamiast `contains(["dev", "test", "staging", "prod"], var.environment)`. Czym różni się trzymanie dozwolonych wartości w zmiennej-liście od wpisania ich wprost w `condition`? Kiedy któreś podejście jest lepsze?

## Dokumentacja

- [Ograniczenia typów (`string`, `number`, `bool`, `list()`, `map()`, `object()`, `optional()`)](https://developer.hashicorp.com/terraform/language/expressions/type-constraints)
- [Walidacja zmiennych (`validation`)](https://developer.hashicorp.com/terraform/language/values/variables)
- [Wyrażenia warunkowe (`? :`)](https://developer.hashicorp.com/terraform/language/expressions/conditionals)
- [Funkcja `contains()`](https://developer.hashicorp.com/terraform/language/functions/contains)
- [Funkcja `regex()`](https://developer.hashicorp.com/terraform/language/functions/regex)
- [Funkcja `can()`](https://developer.hashicorp.com/terraform/language/functions/can)
- [Funkcja `merge()`](https://developer.hashicorp.com/terraform/language/functions/merge)
