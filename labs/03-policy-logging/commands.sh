#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Lab 03 — Policy + Logging (Key Vault -> LA)
# ==========================================
# Cele:
# 1) Zobaczyć jakie Azure Policy ograniczają subskrypcję (np. allowed regions)
# 2) Utworzyć Log Analytics Workspace (LA)
# 3) Podpiąć Diagnostic Settings dla Key Vault -> LA (AuditEvent)
# 4) Wygenerować eventy i odpalić podstawowe KQL (przez az CLI)
#
# Prereq:
# - Masz RG, KV z poprzednich labów
# - KV jest w trybie RBAC
#
# Run:
#   bash labs/03-policy-logging/commands.sh
#
# Po labie:
# - dopisz learnings w labs/03-policy-logging/README.md
# - cleanup (na końcu)

export LOC="${LOC:-swedencentral}"
export RG="${RG:-rg-sec-lab-01}"
export KV="${KV:-kvseclab2137}"
export LAW="${LAW:-law-sec-lab-01}"           # nazwa Log Analytics Workspace
export DIAG_NAME="${DIAG_NAME:-kv-to-law}"     # nazwa diagnostic setting

echo "LOC=$LOC"
echo "RG=$RG"
echo "KV=$KV"
echo "LAW=$LAW"
echo "DIAG_NAME=$DIAG_NAME"

SUB_ID=$(az account show --query id -o tsv)
echo "SUB_ID=$SUB_ID"

# -----------------------
# 1) POLICY: przegląd
# -----------------------
echo ""
echo "=== 1) Azure Policy: assignments (subscription scope) ==="
az policy assignment list --scope "/subscriptions/$SUB_ID" \
  --query "[].{name:name, displayName:displayName, enforcementMode:enforcementMode}" -o table

echo ""
echo "Policy assignments, które wyglądają na 'locations/regions':"
az policy assignment list --scope "/subscriptions/$SUB_ID" \
  --query "[?contains(to_string(displayName),'location') || contains(to_string(displayName),'Location') || contains(to_string(displayName),'region') || contains(to_string(displayName),'Region')].{name:name, displayName:displayName}" -o table

# -----------------------
# 2) LOG ANALYTICS
# -----------------------
echo ""
echo "=== 2) Create Log Analytics Workspace ==="
az monitor log-analytics workspace create -g "$RG" -n "$LAW" -l "$LOC" -o table
LAW_ID=$(az monitor log-analytics workspace show -g "$RG" -n "$LAW" --query id -o tsv)
echo "LAW_ID=$LAW_ID"

# -----------------------
# 3) DIAGNOSTIC SETTINGS
# -----------------------
echo ""
echo "=== 3) Key Vault Diagnostic Settings -> Log Analytics ==="
KV_ID=$(az keyvault show -n "$KV" -g "$RG" --query id -o tsv)
echo "KV_ID=$KV_ID"

echo ""
echo "Dostępne kategorie logów dla Key Vault (sprawdź czy jest AuditEvent):"
az monitor diagnostic-settings categories list --resource "$KV_ID" -o table

# Standardowo Key Vault ma kategorię logów: AuditEvent, a metryki: AllMetrics.
# Jeśli Twoja subskrypcja ma inną nazwę kategorii, komenda poniżej powie error — wtedy zmieniamy category.
echo ""
echo "Tworzę Diagnostic Setting (logs: AuditEvent, metrics: AllMetrics)..."
az monitor diagnostic-settings create \
  --name "$DIAG_NAME" \
  --resource "$KV_ID" \
  --workspace "$LAW_ID" \
  --logs '[{"category":"AuditEvent","enabled":true}]' \
  --metrics '[{"category":"AllMetrics","enabled":true}]' \
  -o table

# -----------------------
# 4) WYGENERUJ EVENTY
# -----------------------
echo ""
echo "=== 4) Generate events (set/get secret) ==="
az keyvault secret set --vault-name "$KV" -n "lab3-secret" --value "from-lab-03" -o none
az keyvault secret show --vault-name "$KV" -n "lab3-secret" --query value -o tsv

echo ""
echo "Uwaga: logi do Log Analytics mogą pojawić się po chwili (to normalne)."

# -----------------------
# 5) KQL przez az CLI
# -----------------------
echo ""
echo "=== 5) KQL (spróbujemy 2 warianty tabel) ==="

echo ""
echo "--- Query A: AzureDiagnostics (najczęstsze dla Diagnostic Settings) ---"
az monitor log-analytics query -w "$LAW_ID" --analytics-query "
AzureDiagnostics
| where ResourceProvider == 'MICROSOFT.KEYVAULT'
| where Resource == '$KV'
| sort by TimeGenerated desc
| take 20
" -o table || true

echo ""
echo "--- Query B: KeyVaultAuditEvents (jeśli workspace ma dedykowaną tabelę) ---"
az monitor log-analytics query -w "$LAW_ID" --analytics-query "
KeyVaultAuditEvents
| where Resource == '$KV'
| sort by TimeGenerated desc
| take 20
" -o table || true

echo ""
echo "Jeśli oba zwracają pusto: powtórz za 2-5 minut i wygeneruj jeszcze raz set/get."

echo ""
echo "=== CLEANUP (stop paying) ==="
echo "Najprościej (kasuje wszystko w lab RG):"
echo "  az group delete -n \"$RG\" --yes --no-wait"
echo ""
echo "Jeśli chcesz zostawić KV, a tylko usunąć LAW + ustawienia diagnostyczne:"
echo "  az monitor diagnostic-settings delete --name \"$DIAG_NAME\" --resource \"$KV_ID\""
echo "  az monitor log-analytics workspace delete -g \"$RG\" -n \"$LAW\" --yes"

