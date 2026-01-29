# Azure Security / DevSecOps Labs (Azure)

## Goal
Hands-on labs to build skills for Cloud Security / DevSecOps (Azure): IAM/RBAC, Key Vault, policies, logging, workload identities.

## How to run labs
- Each lab has its own folder under `labs/`
- Run commands from `commands.sh`
- After each lab: capture learnings in the lab README + clean up resources

## Labs
- 01 Key Vault + RBAC + Secret + Audit
- 02 Managed Identity -> Key Vault (workload identity)




Ogólna składnia (mentalny model)

az <grupa> <podgrupa> <czasownik> [parametry]

grupa = “rzecz” (keyvault / monitor / network / vm / ad / storage)

czasownik = “co robisz” (show / list / create / update / delete / set / assign)

Przykłady:

az keyvault show ...

az monitor diagnostic-settings create ...

az resource list ...



Help na każdym poziomie

az -h
az monitor -h
az monitor diagnostic-settings -h
az monitor diagnostic-settings create -h


az find 

az find "diagnostic settings create"
az find "keyvault secret set"
az find "log analytics query"


--query + -o (JMESPath + formatowanie)

-o tsv do zmiennych

-o table do podglądu

--query ... żeby wyciągać jedno pole
