# 03 — Azure Policy + Logowanie (Key Vault -> Log Analytics) + KQL

## How to run labs
Każdy lab ma folder w `labs/`.
Uruchamiasz `commands.sh`.
Learnings (dopisz po labie)

Jakie policy ograniczają moją subskrypcję i jak je rozpoznałem:

Jak działa Diagnostic Settings i jakie kategorie logów ma Key Vault:

Jakie tabele były dostępne w LA (AzureDiagnostics vs KeyVaultAuditEvents):

Co zobaczyłem w logach po set/get secreta:

## Run
```bash
export LOC="swedencentral"
export RG="rg-sec-lab-01"
export KV="kvseclabXXXXXXXX"
bash labs/03-policy-logging/commands.sh
