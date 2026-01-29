#!/usr/bin/env bash
set -euo pipefail

# --- Variables (adjust if needed) ---
export LOC="swedencentral"
export RG="rg-sec-lab-01"
export TAGS="env=lab owner=szymon purpose=cloud-security"
export KV="${KV:-kvseclab2137}"

# --- Ensure subscription is set (optional) ---
# az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

echo "Using:"
echo "  LOC=$LOC"
echo "  RG=$RG"
echo "  KV=$KV"

# 1) Create Resource Group
az group create -n "$RG" -l "$LOC" --tags $TAGS -o table

# 2) Create Key Vault (RBAC mode)
az keyvault create -n "$KV" -g "$RG" -l "$LOC" --enable-rbac-authorization true -o table

# 3) Assign RBAC role to current user on Key Vault scope
ME=$(az ad signed-in-user show --query id -o tsv)
KVSCOPE=$(az keyvault show -n "$KV" -g "$RG" --query id -o tsv)

az role assignment create \
  --assignee-object-id "$ME" \
  --assignee-principal-type User \
  --role "Key Vault Secrets Officer" \
  --scope "$KVSCOPE"

# 4) Set + get secret
az keyvault secret set --vault-name "$KV" -n "demo-secret" --value "hello-devsecops" -o table
az keyvault secret show --vault-name "$KV" -n "demo-secret" --query value -o tsv

# 5) Audit: Activity Log (resource group)
az monitor activity-log list --resource-group "$RG" --max-events 30 -o table

echo "DONE. If you want to cleanup:"
echo "  az group delete -n \"$RG\" --yes --no-wait"
