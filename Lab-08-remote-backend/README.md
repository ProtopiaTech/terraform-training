# Lab 08 — Backend zdalny: migracja stanu

## Cel

Przenieść lokalny `terraform.tfstate` do zdalnego backendu (Azure Storage), żeby zrozumieć, po co w ogóle backendy istnieją i co daje zdalny stan.

Czas trwania: 45 minut.

Kontynuujemy pracę w `../workshop/`. To ostatni lab warsztatu.

## Wstęp

Z Lab-07 wiemy, że plik stanu zawiera wrażliwe dane i jest jedynym źródłem prawdy o zarządzanych zasobach. Trzymanie go lokalnie na dysku ma poważne wady:

- nikt inny w zespole go nie widzi — współpraca nad tą samą infrastrukturą jest praktycznie niemożliwa,
- nie ma blokady (`lock`) — dwie osoby mogą uruchomić `apply` jednocześnie i uszkodzić stan,
- jeden dysk = jeden punkt awarii, brak backupu.

**Backend** to miejsce, gdzie Terraform trzyma stan i (jeśli backend to wspiera) blokadę na czas operacji. Backend `azurerm` przechowuje stan jako blob w Azure Storage i używa blokady na poziomie bloba.

Storage pod backend nie może być zarządzany przez ten sam Terraform, który będzie w nim trzymał swój stan — to problem "jajko czy kura". Dlatego bootstrapujemy go osobnym skryptem `az` CLI, raz, poza Terraformem.

## Krok 1 — Utwórz storage pod stan

```bash
cd ../Lab-08-remote-backend/scripts
./create-state-storage.sh <nazwa-twojej-grupy-zasobow> <project> <TwojeInicjaly>
```

Podaj te same wartości `project`/`owner`, których używasz w `terraform.tfvars` — skrypt buduje z nich nazwę storage account tą samą konwencją co reszta kursu.

Skrypt jest idempotentny — możesz go uruchomić ponownie bez obawy, że coś popsuje, jeśli storage już istnieje. Zapisz sobie wypisane na końcu wartości (`storage_account_name`, `container_name`).

Wróć do folderu roboczego:

```bash
cd ../../workshop
```

## Krok 2 — Dodaj blok `backend`

Stwórz plik `backend.tf`:

```bash
touch backend.tf
```

```hcl
terraform {
  backend "azurerm" {}
}
```

Pusty blok `backend "azurerm" {}` to celowy wybór — konkretne wartości (nazwa storage, kontenera, klucza) podamy w kroku 3 przez `-backend-config`, żeby nie trzymać ich na sztywno w kodzie (mogą się różnić między środowiskami/uczestnikami).

Ważne ograniczenie typu, na które warto zwrócić uwagę: blok `backend` nie przyjmuje `var.*` ani `local.*` — tylko literały tekstowe (albo `-backend-config`/plik). To celowe: backend musi być znany, zanim Terraform w ogóle wczyta Twoje zmienne, więc nie może od nich zależeć. To jedyne miejsce w całym kursie, gdzie nie możesz użyć zmiennej tam, gdzie normalnie byś jej użył/a.

## Krok 3 — Zmigruj stan

```bash
terraform init -migrate-state \
  -backend-config="resource_group_name=<nazwa-twojej-grupy-zasobow>" \
  -backend-config="storage_account_name=<storage_account_name-ze-skryptu>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=workshop.tfstate"
```

Terraform zapyta, czy skopiować istniejący stan lokalny do nowego backendu — potwierdź `yes`.

## Krok 4 — Zweryfikuj

```bash
terraform plan
```

Powinno wyjść `No changes.` — dokładnie tak samo jak przed migracją, bo zawartość stanu się nie zmieniła, zmieniło się tylko **gdzie** jest przechowywana.

Sprawdź w Azure Portalu kontener `tfstate` — powinien tam być blob `workshop.tfstate`. Lokalny plik `terraform.tfstate` w `workshop/` powinien teraz być właściwie pusty/nieaktualny (Terraform go już nie używa — `.gitignore` i tak by go nie wersjonował).

## Pytania kontrolne

- Dlaczego konfiguracja backendu (`-backend-config`) jest podawana osobno od reszty kodu, zamiast na sztywno w `backend.tf`?
- Co się stanie, jeśli dwie osoby na tym samym backendzie uruchomią `terraform apply` w tym samym momencie?
- Storage pod backend też ma plik stanu... a raczej nie ma — kto/co go "zarządza"? Dlaczego to jest celowe?

## Zadanie dodatkowe

Włącz `versioning_enabled = true` na kontenerze blob w skrypcie bootstrapującym (przez `az storage account blob-service-properties update --enable-versioning true`) i sprawdź w Portalu historię wersji blob `workshop.tfstate` po kolejnym `apply`.

## Sprzątanie

Na koniec kursu:

```bash
terraform destroy
```

usunie wszystkie zasoby utworzone w Twojej grupie zasobów (VNet, Storage Account, Key Vault itd.). Storage pod backend nie zostanie usunięty automatycznie — to zasób poza kontrolą Terraforma; usuń go ręcznie, jeśli już niepotrzebny.

## Dokumentacja

- [Backendy — przegląd](https://developer.hashicorp.com/terraform/language/backend)
- [Backend `azurerm`](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [`terraform init` (w tym `-migrate-state`, `-backend-config`)](https://developer.hashicorp.com/terraform/cli/commands/init)
