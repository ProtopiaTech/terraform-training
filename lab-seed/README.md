# lab-seed

Terraform, który przygotowuje środowisko dla uczestników szkolenia z `../Lab-01...` do `../Lab-10.../` — **to narzędzie prowadzącego, nie materiał kursu**. Dla każdego uczestnika tworzy:

- użytkownika Entra ID z wygenerowanym loginem i hasłem,
- grupę zasobów `rg-<login>`,
- przypisanie roli **Owner** na tej grupie zasobów, tylko dla tego jednego użytkownika.

Dodatkowo tworzy jedną wspólną grupę Entra ID (nazwa z `var.group_name`), do której trafiają wszyscy uczestnicy, i nadaje tej grupie rolę **Reader** na każdej grupie zasobów `rg-<login>`. Dzięki temu uczestnicy widzą nawzajem swoje grupy zasobów (przydatne np. do wspólnych ćwiczeń albo żeby prowadzący nie musiał tego tłumaczyć na żywo), ale nie mają żadnego dostępu poza tymi konkretnymi RG — nie widzą reszty subskrypcji.

Stan trzymany lokalnie.

## Loginy

Nie podajesz listy uczestników — podajesz tylko `trainee_count` (ile kont ma powstać). Loginy generują się same: `user<4 losowe znaki>-<licznik>`, np. `user7f3a-1`, `user7f3a-2`, ... `user7f3a-5`. Losowy sufiks jest wspólny dla całego uruchomienia (odróżnia ten batch od innych) i raz wylosowany zostaje w stanie — zwiększenie `trainee_count` i kolejny `apply` dopisuje kolejne konta, nie zmienia już istniejących.

## Wymagania

- Uprawnienia w Entra ID: rola **User Administrator** lub **Global Administrator** (żeby tworzyć użytkowników i grupę — obie role wystarczają na oba).
- Uprawnienia w Azure: coś, co pozwala tworzyć grupy zasobów i nadawać na nich rolę Owner (np. **Owner** lub **User Access Administrator** na subskrypcji).
- Zalogowany `az login` do właściwego tenanta/subskrypcji.

## Użycie

```bash
cp terraform.tfvars.example terraform.tfvars
# uzupełnij subscription_id, tenant_domain, group_name i trainee_count
terraform init
terraform plan
terraform apply
```

## Odczyt poświadczeń

`terraform apply` wypisze na końcu output `credentials` — mapę licznik → `{user_principal_name, password, resource_group_name}` — **z hasłami w czystym tekście**, celowo. Domyślnie Terraform maskowałby hasło (bo pochodzi z `random_password`, który provider oznacza jako `sensitive`), ale to jest jednorazowy wydruk poświadczeń startowych do przekazania uczestnikom, nie sekret na stałe. Dlatego moduł świadomie używa `nonsensitive()` (patrz `modules/trainee/outputs.tf`).

Żeby odczytać to jeszcze raz później, bez pełnego `apply`:

```bash
terraform output -json credentials | jq
```

**Uwaga:** skoro hasła są odsłonięte, ten output trafi też do historii terminala/logów CI, jeśli tam odpalasz `apply`. Traktuj go tak samo ostrożnie jak same hasła.

## Struktura

- `modules/trainee/` — jedno wywołanie = jeden uczestnik: login + hasło + użytkownik + grupa zasobów + rola Owner + rola Reader dla wspólnej grupy. Moduł sam buduje login z `batch_suffix` i `counter` — root mu tylko podaje te dwie wartości (i `group_object_id` do przypisania roli Reader).
- Root (`main.tf`) tworzy grupę `azuread_group.trainees`, losuje `batch_suffix` raz (`random_string.batch`), woła moduł przez `for_each` po `1..trainee_count`, a na końcu dopisuje każdego utworzonego użytkownika do grupy przez osobny zasób `azuread_group_member` (nie przez `members` na `azuread_group` — to spowodowałoby cykl zależności między grupą a modułem, patrz komentarz w `main.tf`).

## Sprzątanie po szkoleniu

```bash
terraform destroy
```

Usunie wszystkich uczestników (użytkowników Entra ID, ich grupy zasobów i role) utworzonych tym stanem. Upewnij się wcześniej, że uczestnicy nie mają już nic w swoich `rg-<login>`, czego chcesz zachować — `destroy` usuwa grupę zasobów razem z całą jej zawartością.

## Dokumentacja

- [Meta-argument `for_each`](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- [Funkcja `nonsensitive()`](https://developer.hashicorp.com/terraform/language/functions/nonsensitive)
- [Zasób `azuread_user`](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/user)
- [Zasób `azuread_group`](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group)
- [Zasób `azuread_group_member`](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group_member)
- [Zasób `azurerm_resource_group`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group)
- [Zasób `azurerm_role_assignment`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment)
- [Zasób `random_password`](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password)
- [Zasób `random_string`](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string)
