# Lab 01: Key Vault + RBAC + Secret + Audit

## Big picture
- Identity comes from Microsoft Entra ID (your user).
- Authorization is Azure RBAC (role assignment) on a specific scope (Key Vault resource).
- Key Vault stores secrets. RBAC decides who can read/write secrets.

## Definition of done
- Create RG (with tags)
- Create Key Vault in RBAC mode
- Assign yourself "Key Vault Secrets Officer" on KV scope
- Set + Get a secret
- Check Activity Log entries for actions

## Cleanup
- Delete the resource group to avoid costs
