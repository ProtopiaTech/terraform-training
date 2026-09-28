# Lab 01 — Czym jest provider?

## Cel

Poznać podstawowy cykl pracy z Terraform (`init` → `plan` → `apply`) oraz podstawowe typy obiektów (`resource`, `variable`, `output`), zanim w ogóle dotkniemy Azure.

Czas trwania: 40 minut.

## Wstęp

Terraform sam z siebie nie potrafi nic stworzyć — każdą integrację (chmura, lokalny system plików, GitHub, cokolwiek) obsługuje osobny **provider**. W tym labie utworzymy zwykły plik tekstowy na dysku. Nawet do tego Terraform potrzebuje providera — `hashicorp/local`. To dobry punkt startowy: żadnych kont w chmurze, żadnych sekretów, a mechanika jest identyczna jak przy zasobach w Azure.

Typy obiektów, których użyjemy:

- `resource` — zasób zarządzany przez Terraform (tu: plik na dysku)
- `variable` — parametr wejściowy, pozwala na wielokrotne użycie tego samego kodu
- `output` — wartość zwracana po `apply`, np. do dalszego wykorzystania lub podglądu

Przydatne polecenia:

```bash
terraform init      # pobiera providerów, przygotowuje katalog roboczy
terraform validate  # sprawdza poprawność składni
terraform fmt       # formatuje kod
terraform plan      # pokazuje "na sucho", co się zmieni
terraform apply     # wprowadza zmiany
terraform destroy   # usuwa zdefiniowane zasoby
```

## Krok 1 — Zainicjalizuj katalog roboczy

W `../workshop/` stwórz plik `versions.tf`:

```bash
touch versions.tf
```

```hcl
terraform {
  required_version = ">= 1.9"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
```

Uruchom w `workshop/`:

```bash
terraform init
```

Zwróć uwagę na komunikat — Terraform pobrał plugin providera `local` do ukrytego katalogu `.terraform/`. Sprawdź czym jest `.terraform.lock.hcl`, który się właśnie pojawił.

## Krok 2 — Dodaj zmienną i zasób

Stwórz plik `variables.tf`:

```bash
touch variables.tf
```

```hcl
variable "name" {
  description = "Imię/inicjały uczestnika, użyte w treści powitania."
  type        = string
  default     = "Uczestniku"
}
```

`type = string` to najprostszy typ w Terraformie — zwykły tekst. To nie jedyny typ: są też `number` (liczby), `bool` (prawda/fałsz), i typy złożone jak listy czy mapy. Pełny przegląd wszystkich typów i sposobów ich walidacji poznasz w Labie 04 — na razie potrzebujemy tylko `string`.

Stwórz plik `main.tf`:

```bash
touch main.tf
```

```hcl
resource "local_file" "greeting" {
  filename = "${path.module}/greeting.txt"
  content  = "Cześć, ${var.name}! To Twój pierwszy zasób Terraform.\n"
}
```

## Krok 3 — Zaplanuj zmiany

```bash
terraform validate
terraform fmt
terraform plan
```

Przeczytaj plan. Ile zasobów zostanie utworzonych? Skąd Terraform wie, że nic jeszcze nie istnieje?

## Krok 4 — Zaaplikuj

```bash
terraform apply -var="name=<TwojeInicjaly>"
```

Potwierdź przez wpisanie `yes`. Sprawdź, czy powstał plik `greeting.txt` i co zawiera.

## Krok 5 — Zajrzyj do stanu

Po `apply` pojawił się plik `terraform.tfstate`. To jest **jedyne miejsce**, w którym Terraform pamięta, co już utworzył.

```bash
cat terraform.tfstate
```

Znajdź w nim treść `greeting.txt`. Zwróć uwagę, że stan zawiera pełną zawartość zasobu, nie tylko jego nazwę.

Uruchom jeszcze raz, **bez** flagi `-var`:

```bash
terraform plan
```

Zobaczysz propozycję zmiany — Terraform chce podmienić treść pliku z powrotem na `"Cześć, Uczestniku!..."`. To nie błąd: `-var` z Kroku 4 nigdzie się nie zapisał, obowiązywał tylko na czas tamtego jednego polecenia. Bez niego Terraform wraca do wartości domyślnej z `variable "name"`. Stan pamięta, co **jest** wdrożone — nie pamięta, jakich flag użyłeś/aś, żeby to wdrożyć.

Uruchom ponownie z tą samą flagą:

```bash
terraform plan -var="name=<TwojeInicjaly>"
```

Tym razem Terraform nie proponuje żadnych zmian — porównał kod (razem z podanym `-var`) z zapisanym stanem (a przy okazji odświeżył go danymi z rzeczywistego zasobu — to jest krok `refresh`, wykonywany automatycznie przy `plan` i `apply`).

Powtarzanie tej samej flagi przy każdym poleceniu jest niewygodne — dokładnie to naprawia Zadanie dodatkowe poniżej.

## Krok 6 — Dodaj output

Stwórz plik `outputs.tf`:

```bash
touch outputs.tf
```

```hcl
output "greeting_path" {
  description = "Ścieżka do wygenerowanego pliku powitania."
  value       = local_file.greeting.filename
}
```

```bash
terraform apply -var="name=<TwojeInicjaly>"
```

Terraform nie tworzy nic nowego (output nie jest zasobem), ale wyświetla wartość na końcu.

## Pytania kontrolne

- Co by się stało, gdybyś ręcznie usunął(a) `greeting.txt` i uruchomił(a) `terraform plan`?
- Czemu `terraform.tfstate` nie powinien trafiać do repozytorium Git (zobacz `.gitignore` w korzeniu repo)?

## Zadanie dodatkowe

Zamiast podawać `-var="name=..."` przy każdym `apply`, stwórz plik `terraform.tfvars` z zawartością `name = "<TwojeInicjaly>"`. Terraform automatycznie go wczyta. Sprawdź, że `terraform apply` bez żadnej flagi `-var` daje ten sam efekt.

(W Labie 02 poznasz `terraform.tfvars.example` — wzorzec pliku do wersjonowania w Git, bez prawdziwych wartości. Na razie wystarczy zwykły `terraform.tfvars`.)

## Dokumentacja

- [Bloki `resource` — składnia](https://developer.hashicorp.com/terraform/language/resources/syntax)
- [Zmienne wejściowe (`variable`)](https://developer.hashicorp.com/terraform/language/values/variables)
- [Wartości wyjściowe (`output`)](https://developer.hashicorp.com/terraform/language/values/outputs)
- [Wymagania providerów (`required_providers`)](https://developer.hashicorp.com/terraform/language/providers/requirements)
- [Zasób `local_file` (provider `hashicorp/local`)](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file)
