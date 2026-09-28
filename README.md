# Szkolenie: Terraform na Azure

Warsztat wprowadzający do Terraform dla osób bez wcześniejszego doświadczenia z tym narzędziem. 8 godzin, podzielone na dwa dni po 4 godziny, w większości praktyka.

## Wymagania

- Aktywna subskrypcja Azure. **Każdy uczestnik ma własną, dedykowaną grupę zasobów** (Resource Group) przygotowaną przez prowadzącego, z nadanymi uprawnieniami do zarządzania zasobami w jej obrębie. Nazwy zasobów w tym kursie i tak są budowane z Twoich inicjałów (`owner`) i nazwy projektu (`project`), więc nawet gdyby dwie osoby pracowały w tej samej grupie zasobów, nazwy się nie zderzą — ale zakładamy własną grupę na osobę.
- Zainstalowane narzędzia (lub dostęp do Azure Cloud Shell, gdzie są już gotowe) — patrz [Instalacja narzędzi](#instalacja-narzędzi) niżej:
  - Terraform CLI w wersji >= 1.9
  - Azure CLI, zalogowane do właściwej subskrypcji (`az login`)
  - Edytor kodu (np. VS Code z rozszerzeniem HashiCorp Terraform)
- Podstawowa znajomość terminala/wiersza poleceń.

## Instalacja narzędzi

Jeśli pracujesz w Azure Cloud Shell, masz oba narzędzia już zainstalowane — możesz pominąć tę sekcję. Poniżej instrukcje do instalacji lokalnej, na własnym komputerze.

### Terraform CLI

Oficjalna strona instalacji (wybierz swój system): **[developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install)**.

- **macOS** (Homebrew):
  ```bash
  brew tap hashicorp/tap
  brew install hashicorp/tap/terraform
  ```
- **Linux** (Ubuntu/Debian, apt):
  ```bash
  wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update && sudo apt install terraform
  ```
- **Windows**: na stronie instalacji pobierz plik `.zip` dla Windows, rozpakuj i dodaj folder do zmiennej środowiskowej `PATH` (Panel sterowania → Zmienne środowiskowe). Instrukcja krok po kroku jest na stronie linkowanej wyżej.

Weryfikacja (każdy system):

```bash
terraform version
```

### Azure CLI

**Ważne, szczególnie na Windows:** Azure CLI (`az`) to osobne narzędzie od modułu **Azure PowerShell** (`Az.*` cmdlety) — jeśli masz już zainstalowany Azure PowerShell, to *nie* wystarczy do tego kursu. Ten warsztat używa polecenia `az`, dodatkowo Terraform wymaga Azure CLI oddzielnie do uwierzytelniania nawet na Windows.

Oficjalna strona instalacji: **[learn.microsoft.com/cli/azure/install-azure-cli](https://learn.microsoft.com/cli/azure/install-azure-cli)**.

- **Windows** (winget):
  ```powershell
  winget install --exact --id Microsoft.AzureCLI
  ```
  Instrukcja dla Windows (MSI, ZIP, PowerShell): [learn.microsoft.com/cli/azure/install-azure-cli-windows](https://learn.microsoft.com/cli/azure/install-azure-cli-windows)
- **macOS** (Homebrew):
  ```bash
  brew update && brew install azure-cli
  ```
  Szczegóły: [learn.microsoft.com/cli/azure/install-azure-cli-macos](https://learn.microsoft.com/cli/azure/install-azure-cli-macos)
- **Linux** (Debian/Ubuntu, skrypt instalacyjny):
  ```bash
  curl -fsSL 'https://azurecliprod.blob.core.windows.net/$root/deb_install.sh' | sudo bash
  ```
  Inne dystrybucje (RHEL, SUSE, itd.): [learn.microsoft.com/cli/azure/install-azure-cli-linux](https://learn.microsoft.com/cli/azure/install-azure-cli-linux)

Po instalacji, na każdym systemie:

```bash
az version
az login
```

## Jak korzystać z repozytorium

- **`workshop/`** — Twój jedyny folder roboczy. Pracujesz w nim przez cały kurs — pliki `.tf` rosną z laba na lab, tak jak rósłby prawdziwy projekt.
- **`Lab-XX-temat/README.md`** — instrukcje kroku po kroku dla kolejnego labu. Otwórz je w podanej kolejności.
- **`Lab-XX-temat/solution/`** — kompletny, poprawny kod na koniec danego labu (zawiera już wszystko z poprzednich labów). Jeśli utkniesz lub coś nie działa, skopiuj zawartość `solution/` do `workshop/` i idź dalej.

Każdy lab zaczyna się od stanu `workshop/` z poprzedniego labu — nie usuwaj zasobów między labami (poza wyjątkami wyraźnie opisanymi w README danego labu). Wyjątek: **Lab 10** ma dodatkowo folder `broken/` — to nie jest szkielet do uzupełnienia, tylko celowo zepsuty kod do naprawienia (patrz README tego labu). **Lab 09** ma dodatkowo folder `modules/` — to reużywalny moduł, który wywołujesz z `workshop/`, nie edytujesz przez kopiowanie do `workshop/` wprost.

## Agenda

### Dzień 1 (4h)

| Lab | Temat | Orientacyjny czas |
|---|---|---|
| [01](Lab-01-czym-jest-provider/README.md) | Czym jest provider? Proces plan/apply, state | 40 min |
| [02](Lab-02-provider-azure/README.md) | Provider Azure, konfiguracja, `data` | 35 min |
| [03](Lab-03-siec-wirtualna/README.md) | Sieć wirtualna i podsieci | 60 min |
| [04](Lab-04-zmienne-i-tagi/README.md) | Zmienne, `terraform.tfvars`, tagi | 45 min |

### Dzień 2 (4h)

| Lab | Temat | Orientacyjny czas |
|---|---|---|
| [05](Lab-05-lifecycle-i-drift/README.md) | Drift i `lifecycle` | 45 min |
| [06](Lab-06-storage-i-zaleznosci/README.md) | Storage Account, Private Endpoint, zależności | 60 min |
| [07](Lab-07-keyvault-i-state/README.md) | Key Vault, RBAC, plik stanu i sekrety | 45 min |
| [08](Lab-08-remote-backend/README.md) | Backend zdalny — migracja stanu | 45 min |
| [08](Lab-09-moduly/README.md) | Moduły - dzielenie i re-używanie kodu | 45 min |

Czasy są orientacyjne — prowadzący dostosuje tempo do grupy. Dzień 2 bywa ciasny w czasie, bo Lab 07 zależy od propagacji RBAC w Azure, na co nie mamy wpływu. Jeśli grupie brakuje czasu, oba laby bonusowe poniżej odpadają jako pierwsze.

### Bonus

| Lab | Temat | Orientacyjny czas |
|---|---|---|
| [09](Lab-09-moduly/README.md) | Moduły: zbuduj i wywołaj własny moduł Storage Account | 45–60 min |
| [10](Lab-10-debugowanie/README.md) | Debugowanie: czytanie błędów Terraform i Azure (w tym błędy modułów) | 45–60 min |

To materiał dla osób, które skończą wcześniej, albo do zrobienia samodzielnie po kursie. Lab 10 zakłada, że masz już za sobą Lab 09 (moduł `storage` musi istnieć w Twoim `workshop/`).

## Sprzątanie po warsztacie

Na koniec dnia 2, po Labie 08: `terraform destroy` w `workshop/`, żeby usunąć wszystkie utworzone zasoby z Twojej grupy zasobów.
