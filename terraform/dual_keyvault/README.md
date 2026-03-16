# Dual Azure Key Vault Terraform Module

Creates two Azure Key Vaults (source and target) for migration scenarios.

## Usage

```hcl
# Configure variables in terraform.tfvars
subscription_id      = "your-subscription-id"
tenant_id            = "your-tenant-id"
client_id            = "your-client-id"
client_secret        = "your-client-secret"
resource_group_name  = "rg-keyvault"
source_keyvault_name = "kv-source-001"
target_keyvault_name = "kv-target-001"
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | >= 3.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| subscription_id | Azure Subscription ID | string | n/a | yes |
| tenant_id | Azure AD Tenant ID | string | n/a | yes |
| client_id | Service Principal Client ID | string | n/a | yes |
| client_secret | Service Principal Client Secret | string | n/a | yes |
| resource_group_name | Resource group name | string | n/a | yes |
| source_keyvault_name | Source Key Vault name | string | n/a | yes |
| target_keyvault_name | Target Key Vault name | string | n/a | yes |
| location | Azure region | string | eastus | no |
| sku_name | SKU (standard/premium) | string | standard | no |

## Outputs

| Name | Description |
|------|-------------|
| source_keyvault_id | Source Key Vault resource ID |
| source_keyvault_uri | Source Key Vault URI |
| target_keyvault_id | Target Key Vault resource ID |
| target_keyvault_uri | Target Key Vault URI |

## Deployment

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file="terraform.tfvars"

# Apply
terraform apply -var-file="terraform.tfvars"
```

## Migration

After deploying the Key Vaults, use the PowerShell script to copy data:

```powershell
./scripts/copy-keyvault-data.ps1 `
    -SourceVault "kv-source-001" `
    -TargetVault "kv-target-001"
```
