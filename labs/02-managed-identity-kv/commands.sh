#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# Lab 02 — Managed Identity -> Key Vault (Workload Identity)
# =========================================================
# Goal:
#   Use a workload identity (ACI system-assigned Managed Identity) to read a Key Vault secret via RBAC.
#
# Prereq:
#   - Lab 01 completed (Key Vault exists, RBAC enabled, secret "demo-secret" exists)
#   - You exported: RG, LOC, KV
#
# Run:
#   bash labs/02-managed-identity-kv-aci/commands.sh
#
# After lab:
#   - capture learnings in labs/02-managed-identity-kv-aci/README.md
#   - clean up (see bottom)

export LOC="${LOC:-swedencentral}"
export RG="${RG:-rg-sec-lab-01}"
export KV="${KV:?Set KV first. Example: export KV=kvseclab123...}"

# ACI name fixed for predictable cleanup
export ACI_NAME="${ACI_NAME:-aci-mi-lab-01}"

echo "LOC=$LOC"
echo "RG=$RG"
echo "KV=$KV"
echo "ACI_NAME=$ACI_NAME"

# 0) Sanity checks (fail early)
az account show -o table >/dev/null
az group show -n "$RG" -o none
az keyvault show -n "$KV" -g "$RG" -o none

# 1) Create long-running ACI with system-assigned managed identity
# Why long-running: allows `az container exec` without ContainerGroupStopped.
# restart-policy Always keeps it alive for this lab.
echo "Creating ACI (managed identity)..."
az container create -g "$RG" -n "$ACI_NAME" -l "$LOC" \
  --image mcr.microsoft.com/azure-cli \
  --os-type Linux \
  --assign-identity \
  --restart-policy Always \
  --cpu 1 --memory 1 \
  --command-line "sh -c 'while true; do sleep 3600; done'" \
  -o table

# 2) Resolve identity + scope
# principalId = the Entra service principal object behind the managed identity
ACI_PRINCIPAL_ID=$(az container show -g "$RG" -n "$ACI_NAME" --query identity.principalId -o tsv)
KVSCOPE=$(az keyvault show -n "$KV" -g "$RG" --query id -o tsv)

echo "ACI_PRINCIPAL_ID=$ACI_PRINCIPAL_ID"
echo "KVSCOPE=$KVSCOPE"

# 3) RBAC: grant read access on Key Vault scope (least privilege)
# Role: Key Vault Secrets User = read secrets (data plane)
echo "Assigning RBAC role: Key Vault Secrets User (read) on KV scope..."
az role assignment create \
  --assignee-object-id "$ACI_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope "$KVSCOPE" >/dev/null

# 4) Authenticate as workload identity + read the secret
echo "Logging in inside container via managed identity..."
az container exec -g "$RG" -n "$ACI_NAME" --exec-command "az login --identity --allow-no-subscriptions" >/dev/null

echo "Reading Key Vault secret (should succeed)..."
az container exec -g "$RG" -n "$ACI_NAME" --exec-command \
  "az keyvault secret show --vault-name $KV -n demo-secret --query value -o tsv"

# 5) Optional: show the RBAC contrast (remove role -> 403, then add stronger role -> write)
cat <<'TXT'

OPTIONAL (recommended learning loop):
1) Remove read role and confirm you get 403:
   RA_ID=$(az role assignment list --assignee <ACI_PRINCIPAL_ID> --scope <KVSCOPE> --query "[?roleDefinitionName=='Key Vault Secrets User'].id | [0]" -o tsv)
   az role assignment delete --ids "$RA_ID"
   az container exec -g "$RG" -n "$ACI_NAME" --exec-command "az keyvault secret show --vault-name $KV -n demo-secret --query value -o tsv"

2) Add stronger role and write a new secret from workload:
   az role assignment create --assignee-object-id <ACI_PRINCIPAL_ID> --assignee-principal-type ServicePrincipal --role "Key Vault Secrets Officer" --scope <KVSCOPE>
   az container exec -g "$RG" -n "$ACI_NAME" --exec-command "az keyvault secret set --vault-name $KV -n demo-secret-2 --value from-managed-identity -o none"
   az container exec -g "$RG" -n "$ACI_NAME" --exec-command "az keyvault secret show --vault-name $KV -n demo-secret-2 --query value -o tsv"
TXT

echo ""
echo "=== CLEANUP (stop paying) ==="
echo "Delete container:"
echo "  az container delete -g \"$RG\" -n \"$ACI_NAME\" --yes"
echo ""
echo "Delete whole RG (nukes everything):"
echo "  az group delete -n \"$RG\" --yes --no-wait"

