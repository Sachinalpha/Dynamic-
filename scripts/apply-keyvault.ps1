# --------------------------
# Read from environment variables
# --------------------------
$SourceFolder      = ".\kv-data"                  # Use repo folder directly
$TargetVaultName   = $env:TARGET_KEYVAULT_NAME
$TenantId          = $env:AZURE_TENANT_ID
$ClientId          = $env:AZURE_CLIENT_ID
$ClientSecret      = $env:AZURE_CLIENT_SECRET

# --------------------------
# Connect to Azure using Service Principal
# --------------------------
$secureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($ClientId, $secureSecret)
Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $cred

# --------------------------
# Load JSON files
# --------------------------
$secrets        = Get-Content "$SourceFolder/secrets_*.json" | ConvertFrom-Json
$keys           = Get-Content "$SourceFolder/keys_*.json" | ConvertFrom-Json
$certificates   = Get-Content "$SourceFolder/certificates_*.json" | ConvertFrom-Json
$accessPolicies = Get-Content "$SourceFolder/access_policies_*.json" | ConvertFrom-Json
$tags           = Get-Content "$SourceFolder/tags_*.json" | ConvertFrom-Json

# --------------------------
# Apply Secrets
# --------------------------
foreach ($name in $secrets.Keys) {
    $secretData = $secrets[$name]
    Set-AzKeyVaultSecret -VaultName $TargetVaultName `
                         -Name $name `
                         -SecretValue (ConvertTo-SecureString $secretData.Value -AsPlainText -Force) `
                         -Tags $secretData.Tags
}

# --------------------------
# Apply Keys (metadata only)
# --------------------------
foreach ($name in $keys.Keys) {
    $keyData = $keys[$name]
    if (-not (Get-AzKeyVaultKey -VaultName $TargetVaultName -Name $name -ErrorAction SilentlyContinue)) {
        Add-AzKeyVaultKey -VaultName $TargetVaultName `
                          -Name $name `
                          -KeyType $keyData.KeyType `
                          -Enabled $keyData.Enabled `
                          -Expires $keyData.Expires `
                          -Tags $keyData.Tags
    }
}

# --------------------------
# Apply Certificates (metadata only)
# --------------------------
foreach ($name in $certificates.Keys) {
    $certData = $certificates[$name]
    if (-not (Get-AzKeyVaultCertificate -VaultName $TargetVaultName -Name $name -ErrorAction SilentlyContinue)) {
        Add-AzKeyVaultCertificate -VaultName $TargetVaultName `
                                  -Name $name `
                                  -CertificatePolicy (New-AzKeyVaultCertificatePolicy `
                                                        -SubjectName "CN=$name" `
                                                        -IssuerName "Self" `
                                                        -ValidityInMonths 12) `
                                  -Enabled $certData.Enabled
    }
}

# --------------------------
# Apply Access Policies
# --------------------------
foreach ($policy in $accessPolicies) {
    Set-AzKeyVaultAccessPolicy -VaultName $TargetVaultName `
                               -ObjectId $policy.ObjectId `
                               -TenantId $policy.TenantId `
                               -PermissionsToKeys $policy.Permissions.Keys `
                               -PermissionsToSecrets $policy.Permissions.Secrets `
                               -PermissionsToCertificates $policy.Permissions.Certificates
}

# --------------------------
# Apply Tags
# --------------------------
Set-AzKeyVault -VaultName $TargetVaultName -Tags $tags

Write-Host "Key Vault '$TargetVaultName' updated successfully."
