# Lab 10 — Debugowanie: czytanie błędów Terraform i Azure (bonus)

## Cel

Nauczyć się czytać i naprawiać prawdziwe błędy — zarówno te, które łapie `terraform validate` zanim cokolwiek dotknie Azure, jak i te, które ujawniają się dopiero przy realnym `apply` wobec API Azure. Tym razem obejmuje to też typowe pomyłki przy **wywoływaniu modułu** z Laba 09. To umiejętność, której nie da się nauczyć samym pisaniem poprawnego kodu od zera — dlatego cały ten lab zaczynasz od kodu, który **już istnieje i jest zepsuty**.

Czas trwania: 45–60 minut. To lab dodatkowy (bonus) — rób go, jeśli skończyłeś/aś resztę wcześniej, albo samodzielnie po kursie.

## Wstęp

Dodajemy dwa nowe pliki do Twojego `workshop/`:

1. `nsg.tf` — Network Security Group na podsieć Web App, z **czterema** niezależnymi błędami (to samo ćwiczenie co poprzednio, jeśli już je robiłeś/aś — możesz przejść od razu do sekcji o `reports_storage.tf`).
2. `reports_storage.tf` — wywołanie modułu `storage` z Laba 09, z **trzema** kolejnymi błędami, tym razem typowymi dla korzystania z modułów, nie pojedynczych zasobów.

Na marginesie typów (Lab 04): każdy blok `security_rule { ... }` to w praktyce wartość typu `object` — ma kilka pól o różnych typach naraz: `priority` to `number`, `direction`/`access`/`protocol` to `string`. Warto to zauważyć, bo jeden z błędów w `nsg.tf` dotyczy właśnie pola typu `number`.

Nie mówimy Ci wprost, gdzie są błędy — o to chodzi w tym labie. Napraw je jeden po drugim, czytając komunikaty. Jeśli utkniesz na dłużej niż 10 minut na którymś, zerknij do sekcji "Podpowiedzi" niżej. Pełne, poprawne rozwiązanie jest w `solution/`.

## Krok 1 — Upewnij się, że masz stan z Lab-09

Twój `workshop/` powinien zawierać wszystko z Lab-09 (VNet, Storage Account, Key Vault, backend, i moduł `modules/storage/`). Jeśli nie jesteś pewien/pewna, skopiuj `../Lab-09-moduly/solution/*` do `workshop/` (razem z podkatalogiem `modules/`).

## Krok 2 — Wgraj zepsuty kod

```bash
cp ../Lab-10-debugowanie/broken/nsg.tf ./nsg.tf
cp ../Lab-10-debugowanie/broken/reports_storage.tf ./reports_storage.tf
```

(uruchom z `workshop/`). To jedyne dwa nowe/zmienione pliki — reszta configu, łącznie z `modules/storage/`, zostaje bez zmian i jest poprawna.

## Część A — `nsg.tf` (4 błędy)

### Krok 3 — Uruchom `terraform validate` i napraw błąd składni

```bash
terraform validate
```

Terraform poda Ci dokładną linię, w której zaczyna się blok, którego nie potrafi zamknąć. Policz nawiasy klamrowe w `nsg.tf` ręcznie, od góry — gdzie brakuje jednego `}`?

### Krok 4 — Uruchom `terraform validate` ponownie

Po naprawieniu nawiasów zobaczysz **inny** błąd — coś, do czego kod się odwołuje, nie istnieje pod tą nazwą. Terraform w tym przypadku sam podpowiada, co miałeś/aś prawdopodobnie na myśli.

### Krok 5 — Uruchom `terraform validate` jeszcze raz

Trzeci błąd: odwołanie do zasobu, który istnieje w Twoim configu, ale pod **inną nazwą** niż ta użyta w `nsg.tf`. Tym razem Terraform nie zgaduje za Ciebie — musisz sam(a) zajrzeć do `network.tf` z Lab-03, żeby sprawdzić, jak faktycznie nazywa się podsieć webapp.

Po naprawieniu tego błędu `terraform validate` powinno przejść czysto — ale w tym labie, w odróżnieniu od poprzedniej wersji, dopiero teraz zobaczysz błędy z `reports_storage.tf` (parser zatrzymuje się na pierwszym nienaprawionym pliku ze złą składnią, więc dopóki `nsg.tf` miał błąd nawiasów, Terraform nie zdążył nawet zajrzeć głębiej w resztę configu).

## Część B — `reports_storage.tf` (3 błędy)

### Krok 6 — Uruchom `terraform validate` — tym razem kilka błędów naraz

```bash
terraform validate
```

W odróżnieniu od `nsg.tf`, tutaj Terraform pokaże Ci **od razu kilka błędów w bloku `module`** — sprawdzanie argumentów wywołania modułu odbywa się jako jedna całość, nie sekwencyjnie jak przy błędach składni. Wśród nich: brakujący wymagany argument i argument o nazwie, jakiej moduł w ogóle nie zna (znów z podpowiedzią "Did you mean...?").

Napraw oba, aż `terraform validate` przejdzie czysto.

### Krok 7 — `terraform plan` powinien przejść czysto

```bash
terraform plan
```

Jeśli plan przechodzi bez błędów — **nie rób jeszcze `apply`**. Zanim to zrobisz, sprawdź argument `private_endpoint_subnet_id` w bloku `module "reports_storage"`. Wskazuje na istniejącą, poprawną podsieć — więc żaden statyczny check tego nie złapie. Zajrzyj do `network.tf` z Lab-03: która z dwóch podsieci ma tam faktycznie sens jako miejsce na Private Endpoint, a która ma zamiast tego delegację do `Microsoft.Web/serverFarms`?

### Krok 8 — `terraform apply`

```bash
terraform apply
```

Jeśli zostawiłeś/aś podsieć z delegacją z Kroku 7 celowo — Azure API odrzuci utworzenie Private Endpointu, bo podsieć delegowana do konkretnej usługi (tu: `Microsoft.Web/serverFarms`) jest zarezerwowana wyłącznie dla niej i nie może jednocześnie hostować Private Endpointu. To ten sam rodzaj błędu co duplikat priorytetu w `nsg.tf`: wartość poprawna sama w sobie (to prawdziwa, istniejąca podsieć), ale niezgodna z tym, do czego ma służyć — i widoczna dopiero na żywo. Popraw `private_endpoint_subnet_id`, żeby wskazywał na podsieć pod Private Endpointy, i uruchom `apply` ponownie.

## Podpowiedzi (jeśli utkniesz)

- **`nsg.tf`, błąd 1 (składnia):** policz `{` i `}` w każdym bloku `security_rule` osobno — jeden z nich ma o jeden `{` za mało zamknięć.
- **`nsg.tf`, błąd 2 (literówka w tagach):** sprawdź dokładną nazwę local value, którego już używasz od Laba 04 do tagowania innych zasobów w tym pliku.
- **`nsg.tf`, błąd 3 (zła nazwa zasobu):** `grep "resource \"azurerm_subnet\"" network.tf` pokaże Ci obie prawdziwe nazwy podsieci.
- **`nsg.tf`, błąd 4 (Azure, nie Terraform):** oba bloki `security_rule` mają dokładnie tę samą wartość `priority`.
- **`reports_storage.tf`, błąd 1 (brakujący argument):** porównaj listę argumentów w bloku `module "reports_storage"` z listą zmiennych w `modules/storage/variables.tf` — czego brakuje?
- **`reports_storage.tf`, błąd 2 (literówka w argumencie):** komunikat Terraforma dosłownie mówi, co miałeś/aś na myśli.
- **`reports_storage.tf`, błąd 3 (zła podsieć):** która z dwóch podsieci z Laba 03 ma w nazwie "pe", a która "web"?

## Pytania kontrolne

- Dlaczego błędy w `nsg.tf` pojawiały się jeden po drugim, a błędy w `reports_storage.tf` (Krok 6) pojawiły się razem? Co różni sprawdzanie składni pliku od sprawdzania argumentów wywołania modułu?
- Dlaczego błąd 4 w `nsg.tf` i błąd 3 w `reports_storage.tf` nie pojawiły się ani przy `validate`, ani przy `plan` — tylko przy `apply`? Co łączy te dwa przypadki, mimo że dotyczą zupełnie różnych zasobów?
- Moduł `storage` ma tylko jedną zmienną na podsieć (`private_endpoint_subnet_id`), więc nie da się jej "zamienić miejscami" z drugą, jak mogłoby się zdarzyć w module z dwiema podsieciami. Czy to czyni błąd 3 mniej prawdopodobnym, czy tylko zmienia jego charakter? Co by musiało się stać, żeby ten sam typ pomyłki (dobra wartość, zła rola) w ogóle nie był możliwy?

## Zadanie dodatkowe

Dodaj piątą, celowo błędną regułę `security_rule` w `nsg.tf` z `direction = "Wewnatrz"` (nieprawidłowa wartość zamiast `Inbound`/`Outbound`) i sprawdź, na którym etapie (`validate`, `plan` czy `apply`) Terraform to wyłapie. Porównaj z błędem 4 w `nsg.tf` — dlaczego jeden nieprawidłowy string łapie provider lokalnie, a inny (duplikat priorytetu) tylko żywe API?

## Dokumentacja

- [`terraform validate`](https://developer.hashicorp.com/terraform/cli/commands/validate)
- [`terraform plan`](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Zasób `azurerm_network_security_group`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group)
- [Zasób `azurerm_subnet_network_security_group_association`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association)
