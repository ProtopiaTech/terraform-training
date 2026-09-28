# Lab 02 — Provider Azure

## Cel

Skonfigurować provider `azurerm`, połączyć się z prawdziwą subskrypcją Azure, odczytać (nie utworzyć!) istniejącą grupę zasobów, i przygotować zmienne, których będziemy używać do nazywania **wszystkich** zasobów w tym kursie.

Czas trwania: 35 minut.

Kontynuujemy pracę w `../workshop/` — pliki z Lab-01 zostają.

## Wstęp

Provider to plugin, który tłumaczy kod HCL na wywołania konkretnego API — w tym przypadku Azure Resource Manager. Provider trzeba zadeklarować w dwóch miejscach:

1. w bloku `required_providers` (jakiej wersji chcemy, skąd ją pobrać),
2. w bloku `provider "azurerm" { ... }` (jak się z nim połączyć — subskrypcja, opcje).

`data` to nowy typ obiektu: pozwala **odczytać** informacje o zasobie, który już istnieje, bez przejmowania nad nim zarządzania przez Terraform. Twoja grupa zasobów już istnieje (utworzył ją prowadzący) — użyjemy `data`, żeby się do niej odwołać.

Wszystkie cztery zmienne w tym labie (`subscription_id`, `resource_group_name`, `project`, `owner`) mają `type = string` — nawet `subscription_id`, który wygląda jak specjalny identyfikator (GUID), dla Terraforma jest zwykłym tekstem. Typy w Terraformie opisują *kształt* danych (tekst, liczba, lista...), a nie ich znaczenie biznesowe — to, że coś jest identyfikatorem, sprawdza się przez `validation`, nie przez `type`. Pełny przegląd typów jest w Labie 04.

Przy okazji dodamy dwie zmienne, `project` i `owner`, których nie użyjemy jeszcze w tym labie (nic tu nie tworzymy), ale które od Laba 03 będą wchodzić w nazwę **każdego** zasobu, jaki utworzysz w tym kursie — to zapobiega kolizjom nazw (np. gdyby dwie osoby dzieliły grupę zasobów, albo gdybyś uruchamiał(a) kurs drugi raz). Obie mają blok `validation` — nie tłumaczymy go teraz dokładnie (wrócimy do tego w Labie 04), na razie traktuj go jako "strażnika" pilnującego długości i dozwolonych znaków. To ważne, bo za dwa laby (06 i 07) `owner`/`project` trafią w nazwę Storage Account i Key Vault, które muszą być globalnie unikalne i mieszczą się w limicie 24 znaków — łatwiej złapać zbyt długą wartość teraz niż dostać niezrozumiały błąd Azure później.

## Krok 1 — Zaloguj się do Azure CLI

Jeśli pracujesz lokalnie (nie w Cloud Shell):

```bash
az login
az account set --subscription "<nazwa-lub-id-subskrypcji>"
az account show --query id -o tsv
```

Zapisz sobie wynik ostatniej komendy — to Twój `subscription_id`.

## Krok 2 — Rozszerz `versions.tf`

Dopisz provider `azurerm` obok istniejącego `local`:

```hcl
terraform {
  required_version = ">= 1.9"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.7"
    }
  }
}
```

## Krok 3 — Skonfiguruj provider

Stwórz plik `providers.tf`:

```bash
touch providers.tf
```

```hcl
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
```

Blok `features {}` jest wymagany nawet pusty — steruje domyślnymi zachowaniami providera (np. czy przy usuwaniu Key Vault ma być on trwale czyszczony — wrócimy do tego w Labie 07).

## Krok 4 — Dodaj zmienne wejściowe

Dopisz do `variables.tf`:

```hcl
variable "subscription_id" {
  description = "ID subskrypcji Azure."
  type        = string
}

variable "resource_group_name" {
  description = "Nazwa istniejącej grupy zasobów przygotowanej na warsztat."
  type        = string
}

variable "project" {
  description = "Krótki identyfikator projektu, używany w nazwach zasobów."
  type        = string
  default     = "tftrain"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,8}$", var.project))
    error_message = "project: tylko małe litery, cyfry i myślniki, 2-8 znaków."
  }
}

variable "owner" {
  description = "Twoje inicjały — wchodzą w nazwę każdego zasobu, żeby uniknąć kolizji (w tym globalnych, np. Storage Account)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.owner))
    error_message = "owner: tylko małe litery i cyfry, 2-6 znaków."
  }
}
```

Stwórz plik `terraform.tfvars.example` (wzorzec do skopiowania, bez prawdziwych wartości w repo):

```bash
touch terraform.tfvars.example
```

```hcl
subscription_id     = "00000000-0000-0000-0000-000000000000"
resource_group_name = "rg-nazwa-twojej-grupy"
project             = "tftrain"
owner               = "<twoje-inicjaly-malymi-literami>"
```

```bash
cp terraform.tfvars.example terraform.tfvars
```

Uzupełnij `terraform.tfvars` swoimi wartościami (`owner` małymi literami, np. `wg`, `ajk`). Ten plik jest już objęty `.gitignore` — nie trafi do repozytorium.

## Krok 5 — Odczytaj istniejącą grupę zasobów

Stwórz plik `data.tf`:

```bash
touch data.tf
```

```hcl
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}
```

Dopisz do `outputs.tf`:

```hcl
output "resource_group_location" {
  description = "Lokalizacja (region) grupy zasobów."
  value       = data.azurerm_resource_group.main.location
}
```

## Krok 6 — Zainicjalizuj i zaaplikuj

```bash
terraform init
# Wyskoczył błąd?
terraform init -upgrade
terraform validate
terraform apply
```

Zwróć uwagę: `plan` pokazuje, że **żaden nowy zasób w Azure nie powstanie** — `data` tylko odczytuje, a `project`/`owner` na razie nigdzie się nie używają. Sprawdź output `resource_group_location`.

**Porządki (opcjonalnie):** `local_file.greeting` z Laba 01 wciąż jest w `main.tf` — był tylko po to, żeby poznać cykl `init`/`plan`/`apply` bez dotykania Azure. Możesz go teraz spokojnie usunąć razem z providerem `local` w `versions.tf` (i plikiem `greeting.txt`) — od tego labu pracujemy już na prawdziwych zasobach. W tym kursie zostawiamy go celowo przez resztę materiału, żeby `workshop/` zawsze dało się porównać z `solution/` danego labu — ale to Twój config, nie nasz wymóg.

## Pytania kontrolne

- Czym różni się `resource` od `data` pod względem tego, co Terraform robi przy `apply` i `destroy`?
- Spróbuj celowo ustawić `owner = "a"` (jeden znak) w `terraform.tfvars` i uruchom `terraform plan`. Co się dzieje i dlaczego to lepsze niż dowiedzieć się o limicie długości dopiero w Labie 06?

## Zadanie dodatkowe

Dodaj kolejny output pokazujący `data.azurerm_resource_group.main.id` (pełny ARM resource ID) i porównaj go z tym, co widzisz w Azure Portal.

## Dokumentacja

- [Konfiguracja providera (`provider { ... }`)](https://developer.hashicorp.com/terraform/language/providers/configuration)
- [Źródła danych (`data`)](https://developer.hashicorp.com/terraform/language/data-sources)
- [Walidacja zmiennych (`validation`)](https://developer.hashicorp.com/terraform/language/values/variables)
- [Provider `azurerm` — dokumentacja](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Źródło danych `azurerm_resource_group`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group)
