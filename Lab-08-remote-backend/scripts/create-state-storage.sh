#!/usr/bin/env bash
# Tworzy storage account + kontener pod zdalny stan Terraform.
# Uruchamiane RAZ, poza Terraformem (nie może zarządzać sam sobą jako backend).
#
# Użycie:
#   ./create-state-storage.sh <resource_group_name> <project> <owner_initials>
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Użycie: $0 <resource_group_name> <project> <owner_initials>" >&2
  exit 1
fi

RESOURCE_GROUP_NAME="$1"
PROJECT="$(echo "$2" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
OWNER="$(echo "$3" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
STORAGE_ACCOUNT_NAME="tfstate${PROJECT}${OWNER}"
CONTAINER_NAME="tfstate"

echo "Grupa zasobów:    ${RESOURCE_GROUP_NAME}"
echo "Storage account:   ${STORAGE_ACCOUNT_NAME}"
echo "Kontener:          ${CONTAINER_NAME}"

if [[ ${#STORAGE_ACCOUNT_NAME} -gt 24 ]]; then
  echo "Błąd: nazwa storage account '${STORAGE_ACCOUNT_NAME}' ma ${#STORAGE_ACCOUNT_NAME} znaków, limit to 24. Skróć project/owner." >&2
  exit 1
fi

if az storage account show --name "${STORAGE_ACCOUNT_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" &>/dev/null; then
  echo "Storage account ${STORAGE_ACCOUNT_NAME} już istnieje — pomijam tworzenie."
else
  az storage account create \
    --name "${STORAGE_ACCOUNT_NAME}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false
fi

az storage container create \
  --name "${CONTAINER_NAME}" \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --auth-mode login

cat <<EOF

Gotowe. Użyj tych wartości w 'terraform init -backend-config=...':

  resource_group_name = "${RESOURCE_GROUP_NAME}"
  storage_account_name = "${STORAGE_ACCOUNT_NAME}"
  container_name       = "${CONTAINER_NAME}"
  key                  = "workshop.tfstate"
EOF
