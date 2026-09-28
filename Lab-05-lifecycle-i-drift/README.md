# Lab 05 — Drift i `lifecycle`

## Cel

Zobaczyć na żywo, czym jest **drift** (rozjazd między stanem a rzeczywistością), i nauczyć się nim świadomie zarządzać przez blok `lifecycle`.

Czas trwania: 45 minut.

Kontynuujemy pracę w `../workshop/`.

## Wstęp — historyjka

Zespół Compliance w firmie ręcznie zarządza tagiem `gdpr` na części zasobów przez osobne narzędzie (np. Azure Policy z `modify` effect) — poza Terraformem. Jeśli Terraform przy każdym `apply` nadpisuje ten tag z powrotem na wartość z kodu, wojna między dwoma systemami nigdy się nie skończy. Musimy nauczyć Terraform: "tym jednym polem się nie przejmuj".

## Krok 1 — Wywołaj drift ręcznie

Twój VNet nazywa się teraz `vnet-${project}-${owner}`, nie na sztywno — pobierz jego ID z outputu zamiast zgadywać nazwę:

```bash
VNET_ID=$(terraform output -raw vnet_id)
echo "$VNET_ID"
```

Zmień tag `gdpr` na `confidential`, dotykając **tylko tego jednego pola** (żeby nie ryzykować nadpisania innych tagów literówką):

```bash
az resource update --ids "$VNET_ID" --set tags.gdpr=confidential
```

Jeśli wolisz zrobić to ręcznie: otwórz VNet w Portalu → Tags → zmień `gdpr` na `confidential` → Save. Oba sposoby dają ten sam efekt — CLI jest tu tylko szybsze.

## Krok 2 — Zobacz drift

```bash
terraform plan
```

Terraform wykrywa różnicę i proponuje przywrócić `gdpr = "public"` — bo tak jest w kodzie. To jest **drift**: ktoś/coś zmieniło zasób poza Terraformem, a Terraform próbuje wrócić do zgodności z kodem.

**Nie rób `apply`** — najpierw naprawimy to poprawnie.

## Krok 3 — Zignoruj zmiany na tagu `gdpr`

W `network.tf`, w zasobie `azurerm_virtual_network.main`, dodaj blok `lifecycle`:

```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}"
  address_space       = ["10.20.0.0/16"]
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = local.vnet_tags

  lifecycle {
    ignore_changes = [tags["gdpr"]]
  }
}
```

`ignore_changes` mówi Terraformowi: "przy porównywaniu stanu z rzeczywistością, to konkretne pole traktuj jako nieistotne — nie proponuj dla niego zmian, w żadną stronę".

Uwaga na typ: `ignore_changes` przyjmuje **listę odwołań do atrybutów** (`tags["gdpr"]`, `tags`, `address_space`), nie listę tekstów w cudzysłowie — to nie jest `list(string)` z nazwami pól, tylko wyrażenia wskazujące konkretne miejsce w schemacie zasobu. Dlatego `tags["gdpr"]` bez cudzysłowu wokół całego wyrażenia (choć `"gdpr"` w środku jako klucz mapy jest tekstem).

## Krok 4 — Zweryfikuj

```bash
terraform plan
```

Tym razem plan powinien być pusty (`No changes.`) — mimo że `gdpr` w Azure (`confidential`) różni się od wartości w `local.vnet_tags` (`public`). Terraform świadomie to ignoruje.

```bash
terraform apply
```

Nic się nie zmienia — co jest oczekiwanym efektem.

## Krok 5 — Sprawdź, że reszta tagów wciąż działa

Zmień w `terraform.tfvars` `environment` na `test` i uruchom `terraform plan`. Powinieneś zobaczyć aktualizację `environment`, ale **nie** `gdpr` — `ignore_changes` działa na poziomie pojedynczego klucza mapy, nie całego bloku `tags`. Wróć `environment` do `dev` po teście.

## Pytania kontrolne

- Czym różni się `ignore_changes = [tags["gdpr"]]` od `ignore_changes = [tags]`?
- Gdyby zamiast pojedynczego tagu ktoś ręcznie zmienił `address_space` na VNet, co pokazałby `terraform plan`? Czy `lifecycle` z kroku 3 miałoby na to wpływ?
- Kiedy `ignore_changes` jest dobrym rozwiązaniem, a kiedy jest tylko maskowaniem prawdziwego problemu (np. brakującego uprawnienia w Terraformie)?

## Zadanie dodatkowe

Dodaj `prevent_destroy = true` w tym samym bloku `lifecycle` i spróbuj (tylko w planie, bez realnego wykonania) `terraform plan -destroy` — zobacz, jak Terraform odmawia.

## Dokumentacja

- [Meta-argument `lifecycle` (`ignore_changes`, `prevent_destroy`)](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [Plik stanu — jak Terraform go używa](https://developer.hashicorp.com/terraform/language/state)
