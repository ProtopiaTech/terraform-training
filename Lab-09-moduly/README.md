# Lab 09 — Moduły (bonus)

## Cel

Zrozumieć, czym jest moduł w Terraformie, i zbudować pierwszy własny: moduł "storage" (Storage Account + Private Endpoint), który przyjmuje dane wejściowe i zwraca konkretne wyjścia — dokładnie tak, jak każdy zasób providera.

Czas trwania: 45–60 minut. To lab dodatkowy (bonus), podobnie jak Lab 10.

Kontynuujemy pracę w `../workshop/` — wszystko z Lab-08 (VNet, Storage Account, Key Vault, backend) zostaje.

## Wstęp

Do tej pory Twój cały config leżał w jednym katalogu (`workshop/`) — to jest **root module**, korzeń Twojej konfiguracji. Terraform pozwala wydzielić kawałek configu do osobnego katalogu i wywoływać go wielokrotnie, z różnymi wartościami — to jest **child module**.

Po co to robić?

- **Ponowne użycie** — jeśli za miesiąc ktoś będzie potrzebował kolejnego konta Storage z Private Endpointem w innym projekcie, kopiuje wywołanie modułu, nie 20 linii kodu zasobów.
- **Jasny interfejs** — moduł ma zdefiniowane wejścia (`variables.tf`) i wyjścia (`outputs.tf`). Ten, kto go wywołuje, nie musi wiedzieć, że w środku jest `azurerm_storage_account` + `azurerm_private_endpoint` — widzi tylko: "podaj mi grupę zasobów, tagi, podsieć; dostaniesz ID konta i jego prywatny adres IP".
- **Enkapsulacja** — szczegóły implementacji (konwencja nazewnictwa, `public_network_access = "Disabled"`) są schowane w module. Zmienisz je w jednym miejscu, wszystkie wywołania korzystają z poprawki.

Zwróć uwagę: struktura plików modułu (`variables.tf`, `main.tf`, `outputs.tf`) to dokładnie ta sama konwencja, której używasz w `workshop/` od Laba 01 — moduł to po prostu config, tylko wywoływany z zewnątrz zamiast bezpośrednio przez `terraform apply`.

Ten moduł to w gruncie rzeczy **to, co już napisałeś/aś ręcznie w Labie 06** (Storage Account bez publicznego dostępu + Private Endpoint) — opakowane tak, żeby dało się to powtórzyć bez kopiowania kodu za każdym razem, gdy kolejny projekt będzie potrzebował tego samego wzorca. Nowego typu zasobu tu nie ma; nowa jest tylko forma.

Moduł potrzebuje tylko podsieci pod Private Endpointy z Laba 03 (`snet-pe-${local.name_prefix}`) — nie tej z delegacją dla Web App. Ta druga podsieć (`snet-web-${local.name_prefix}`) zostaje w Twoim `workshop/` jako demonstracja koncepcji delegacji z Laba 03, ale żaden lab w tym kursie już jej faktycznie nie użyje — to świadomy kompromis (pierwotnie ten lab budował moduł Web App, ale App Service to zasób typu compute, a niektóre subskrypcje mają na to twardy limit; Storage Account nim nie jest, więc lab działa bez tego ograniczenia).

## Krok 1 — Utwórz strukturę modułu

W `workshop/` stwórz katalog `modules/storage/`. Wszystko poniżej trafia do tego katalogu, nie do `workshop/` bezpośrednio.

## Krok 2 — Zdefiniuj wejścia modułu

Stwórz `modules/storage/variables.tf`:

```hcl
variable "resource_group_name" {
  description = "Nazwa grupy zasobów, w której powstaną zasoby modułu."
  type        = string
}

variable "location" {
  description = "Region Azure."
  type        = string
}

variable "name_prefix" {
  description = "Prefiks nazw zasobów (np. \"tftrain-agent-reports\") — moduł sam oczyszcza go do wymogów Storage Account."
  type        = string
}

variable "tags" {
  description = "Tagi do zastosowania na wszystkich zasobach modułu."
  type        = map(string)
  default     = {}
}

variable "account_tier" {
  description = "Warstwa wydajności Storage Account."
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Typ replikacji Storage Account."
  type        = string
  default     = "LRS"
}

variable "private_endpoint_subnet_id" {
  description = "ID podsieci pod Private Endpointy — tu powstanie prywatny punkt dostępu do konta."
  type        = string
}
```

To jest cały "interfejs" modułu — nic więcej z zewnątrz nie da się do niego wstrzyknąć. Zwróć uwagę, że moduł nie zna `var.owner` ani `var.project` z Twojego roota — dostaje gotowy `name_prefix` jako zwykły string. Moduł nie powinien wiedzieć nic o tym, skąd pochodzą jego dane wejściowe. Zwróć też uwagę na `private_endpoint_subnet_id` — to jedyna podsieć, jakiej moduł potrzebuje; **Private Endpoint jest tu parametrem wejściowym modułu**, nie czymś zaszytym na sztywno w środku.

## Krok 3 — Napisz zasoby modułu

Stwórz `modules/storage/main.tf`:

```hcl
locals {
  # Storage Account: twardy limit Azure — 3-24 znaki, tylko małe litery i cyfry.
  # Moduł sam pilnuje własnej konwencji nazewnictwa, niezależnie od tego, co
  # dostał w name_prefix (ten sam wzorzec co w Labie 06, tu opakowany w moduł).
  storage_account_name = substr(lower(replace("st${var.name_prefix}", "/[^a-zA-Z0-9]/", "")), 0, 24)
}

resource "azurerm_storage_account" "this" {
  name                = local.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type

  public_network_access = "Disabled"

  tags = var.tags
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.name_prefix}"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  tags = var.tags
}
```

Zauważ: moduł sam liczy `storage_account_name` ze swojego `var.name_prefix` — nie oczekuje, że wołający poda mu już gotową, oczyszczoną nazwę. To celowe: logika "jak zbudować poprawną nazwę tego konkretnego typu zasobu" należy do modułu, nie do roota, bo to moduł wie, jakie ograniczenia ma zasób, którym zarządza.

## Krok 4 — Zdefiniuj wyjścia modułu

Stwórz `modules/storage/outputs.tf`:

```hcl
output "storage_account_id" {
  value = azurerm_storage_account.this.id
}

output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "private_endpoint_ip" {
  value = azurerm_private_endpoint.this.private_service_connection[0].private_ip_address
}
```

Tylko to, co tu zadeklarujesz, będzie widoczne na zewnątrz modułu.

## Krok 5 — Wywołaj moduł z roota

Wróć do `workshop/` (poziom wyżej) i stwórz `reports_storage.tf`:

```hcl
module "reports_storage" {
  source = "./modules/storage"

  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = data.azurerm_resource_group.main.location
  name_prefix                = "${local.name_prefix}-reports"
  tags                       = local.common_tags
  private_endpoint_subnet_id = azurerm_subnet.private_endpoints.id
}
```

Zwróć uwagę na symetrię: argumenty w bloku `module` to dokładnie te same nazwy, które zadeklarowałeś/aś jako `variable` w Kroku 2 — moduł nie zgaduje, czego chcesz, tylko czyta to, co mu podałeś pod nazwą, jaką sam zdefiniował. `name_prefix = "${local.name_prefix}-reports"` odróżnia to konto od tego z Laba 06 (to samo `local.name_prefix`, ale z dopiskiem — inaczej nazwy by się zderzyły).

## Krok 6 — Zainicjalizuj ponownie

```bash
terraform init
```

**To nie jest przypadek, że każemy Ci to zrobić ponownie.** Terraform musi "zobaczyć" nowy moduł przy `init`, zanim będzie mógł go użyć w `plan`/`apply` — dodanie albo zmiana `source` w bloku `module` zawsze wymaga ponownego `init`. To jeden z najczęstszych "dlaczego to nie działa" u osób, które dopiero zaczynają z modułami.

```bash
terraform validate
terraform plan
```

Przyjrzyj się adresom zasobów w planie: `module.reports_storage.azurerm_storage_account.this`, `module.reports_storage.azurerm_private_endpoint.this` — moduł dostaje własny "namespace" wewnątrz stanu, żeby dwa wywołania tego samego modułu (patrz Zadanie dodatkowe) nigdy się nie zderzyły.

```bash
terraform apply
```

## Krok 7 — Dodaj output odwołujący się do modułu

Dopisz do `outputs.tf`:

```hcl
output "reports_storage_account_id" {
  value = module.reports_storage.storage_account_id
}
```

Odwołanie do wyjścia modułu z roota zawsze ma postać `module.<nazwa_wywołania>.<nazwa_output>` — `reports_storage` to nazwa, którą nadałeś/aś w bloku `module "reports_storage" { ... }` w Kroku 5, nie nazwa katalogu ani nazwa samego modułu.

## Pytania kontrolne

- Dlaczego moduł przyjmuje `name_prefix` jako gotowy string, zamiast przyjmować `project` i `owner` osobno i sam sobie budować prefiks?
- Co by się stało, gdybyś spróbował(a) odwołać się z roota do `module.reports_storage.azurerm_storage_account.this.id` zamiast `module.reports_storage.storage_account_id`?
- Dlaczego trzeba było ponownie odpalić `terraform init` po dodaniu bloku `module`, skoro provider `azurerm` już był zainicjalizowany?
- Dlaczego moduł sam liczy `storage_account_name` (Krok 3), zamiast oczekiwać gotowej nazwy jako argument, tak jak `resource_group_name` czy `location`?

## Zadanie dodatkowe

Wywołaj moduł **drugi raz**, pod inną nazwą, np. `module "backups_storage" { source = "./modules/storage"; name_prefix = "${local.name_prefix}-backups"; ... }`, z tą samą podsiecią. To jest właściwy sens modułów: ten sam kod, dwa niezależne zasoby, zero kopiowania. Sprawdź w `terraform plan`, że oba wywołania mają osobne adresy (`module.reports_storage.*` i `module.backups_storage.*`) i nie kolidują ze sobą.

## Dokumentacja

- [Moduły — przegląd](https://developer.hashicorp.com/terraform/language/modules)
- [Budowa modułów (struktura plików, wejścia, wyjścia)](https://developer.hashicorp.com/terraform/language/modules/develop)
- [Zasób `azurerm_storage_account`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account)
- [Zasób `azurerm_private_endpoint`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint)
