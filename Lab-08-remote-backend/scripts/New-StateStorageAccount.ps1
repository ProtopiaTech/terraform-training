#!/usr/bin/env pwsh
# Tworzy storage account + kontener pod zdalny stan Terraform.
# Uruchamiane RAZ, poza Terraformem (nie może zarządzać sam sobą jako backend).
#
# Wymaga modułu Az.Storage i Az.Resources (zalogowanie: Connect-AzAccount).
#
# Użycie:
#   ./New-StateStorageAccount.ps1 <resource_group_name> <project> <owner_initials>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Project,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]$OwnerInitials
)

$ErrorActionPreference = "Stop"

function ToSlug([string]$Value) {
    return ($Value.ToLower() -replace '[^a-z0-9]', '')
}

$ProjectSlug = ToSlug $Project
$OwnerSlug = ToSlug $OwnerInitials
$StorageAccountName = "tfstate${ProjectSlug}${OwnerSlug}"
$ContainerName = "tfstate"

Write-Host "Grupa zasobów:    $ResourceGroupName"
Write-Host "Storage account:   $StorageAccountName"
Write-Host "Kontener:          $ContainerName"

if ($StorageAccountName.Length -gt 24) {
    Write-Error "Błąd: nazwa storage account '$StorageAccountName' ma $($StorageAccountName.Length) znaków, limit to 24. Skróć project/owner."
    exit 1
}

$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue

if ($storageAccount) {
    Write-Host "Storage account $StorageAccountName już istnieje — pomijam tworzenie."
}
else {
    $storageAccount = New-AzStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName `
        -SkuName Standard_LRS `
        -Kind StorageV2 `
        -MinimumTlsVersion TLS1_2 `
        -AllowBlobPublicAccess $false
}

# Kontekst z uwierzytelnieniem Azure AD (odpowiednik `az storage ... --auth-mode login`).
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

$container = Get-AzStorageContainer -Name $ContainerName -Context $ctx -ErrorAction SilentlyContinue
if ($container) {
    Write-Host "Kontener $ContainerName już istnieje — pomijam tworzenie."
}
else {
    New-AzStorageContainer -Name $ContainerName -Context $ctx -Permission Off | Out-Null
}

Write-Host ""
Write-Host "Gotowe. Użyj tych wartości w 'terraform init -backend-config=...':"
Write-Host ""
Write-Host "  resource_group_name  = `"$ResourceGroupName`""
Write-Host "  storage_account_name = `"$StorageAccountName`""
Write-Host "  container_name       = `"$ContainerName`""
Write-Host "  key                  = `"workshop.tfstate`""
