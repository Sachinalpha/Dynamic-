# --------------------------
# Read environment variables
# --------------------------
$TargetVaultName   = $env:TARGET_KEYVAULT_NAME
$SubscriptionId    = $env:AZURE_SUBSCRIPTION_ID
$TenantId          = $env:AZURE_TENANT_ID
$ClientId          = $env:AZURE_CLIENT_ID
$ClientSecret      = $env:AZURE_CLIENT_SECRET
$SourceFolder      = "$PSScriptRoot/../kv-data"  # adjust if scripts folder changes

Write-Host "Target Key Vault: $TargetVaultName"
Write-Host "Source folder: $SourceFolder"

# --------------------------
# Install / Import Az module
# --------------------------
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -Scope CurrentUser -Force -AllowClobber
}
Import-Module Az -Force
Import-Module Az.KeyVault -Force

# --------------------------
# Login to Azure using SP
# --------------------------
$secureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($ClientId, $secureSecret)
Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $cred
Set-AzContext -Subscription $SubscriptionId

# --------------------------
# Fetch JSON files
# --------------------------
$secretsFile = Get-ChildItem "$SourceFolder/secrets_*.json" -ErrorAction SilentlyContinue | Select-Object -First 1
$keysFile    = Get-ChildItem "$SourceFolder/keys_*.json" -ErrorAction SilentlyContinue | Select-Object -First 1
$certFile    = Get-ChildItem "$SourceFolder/certificates_*.json" -ErrorAction SilentlyContinue | Select-Object -First 1
$apFile      = Get-ChildItem "$SourceFolder/access_policies_*.json" -ErrorAction SilentlyContinue | Select-Object -First 1
$tagsFile    = Get-ChildItem "$SourceFolder/tags_*.json" -ErrorAction SilentlyContinue | Select-Object -First 1

$secrets     = if ($secretsFile) { Get-Content $secretsFile | ConvertFrom-Json } else { @{}; Write-Host "No secrets JSON found" }
$keys        = if ($keysFile)    { Get-Content $keysFile    | ConvertFrom-Json } else { @{}; Write-Host "No keys JSON found" }
$certificates= if ($certFile)    { Get-Content $certFile    | ConvertFrom-Json } else { @{}; Write-Host "No certificates JSON found" }
$accessPolicies = if ($apFile)   { Get-Content $apFile      | ConvertFrom-Json } else { @(); Write-Host "No access policies JSON found" }
$tags        = if ($tagsFile)    { Get-Content $tagsFile    | ConvertFrom-Json } else { @{}; Write-Host "No tags JSON found" }

# --------------------------
# Apply Secrets
# --------------------------
if ($secrets.Keys.Count -eq 0) { Write-Host "No secrets to apply." } else {
    foreach ($name in $secrets.Keys) {
        $secretData = $secrets[$name]
        if ($secretData) {
            Set-AzKeyVaultSecret -VaultName $TargetVaultName `
                                 -Name $name `
                                 -SecretValue (ConvertTo-SecureString $secretData -AsPlainText -Force)
            Write-Host "Secret '$name' applied."
        } else { Write-Host "Secret '$name' is empty, skipping." }
    }
}

# --------------------------
# Apply Keys
# --------------------------
if ($keys.Keys.Count -eq 0) { Write-Host "No keys to apply." } else {
    foreach ($name in $keys.Keys) {
        $keyData = $keys[$name]
        if ($keyData.KeyType) {
            $existingKey = Get-AzKeyVaultKey -VaultName $TargetVaultName -Name $name -ErrorAction SilentlyContinue
            if (-not $existingKey) {
                Add-AzKeyVaultKey -VaultName $TargetVaultName `
                                  -Name $name `
                                  -KeyType $keyData.KeyType `
                                  -KeyOps @("encrypt","decrypt","sign","verify","wrapKey","unwrapKey")
                Write-Host "Key '$name' created."
            } else { Write-Host "Key '$name' already exists. Skipping." }
        } else { Write-Host "Key '$name' data empty, skipping." }
    }
}

# --------------------------
# Apply Certificates
# --------------------------
if ($certificates.Keys.Count -eq 0) { Write-Host "No certificates to apply." } else {
    foreach ($name in $certificates.Keys) {
        $certData = $certificates[$name]
        $existingCert = Get-AzKeyVaultCertificate -VaultName $TargetVaultName -Name $name -ErrorAction SilentlyContinue
        if (-not $existingCert) {
            Add-AzKeyVaultCertificate -VaultName $TargetVaultName `
                                      -Name $name `
                                      -CertificatePolicy (New-AzKeyVaultCertificatePolicy -SubjectName "CN=$name" -IssuerName "Self")
            Write-Host "Certificate '$name' created (self-signed)."
        } else { Write-Host "Certificate '$name' already exists. Skipping." }
    }
}

# --------------------------
# Apply Access Policies
# --------------------------
if ($accessPolicies.Count -eq 0) { Write-Host "No access policies to apply." } else {
    foreach ($policy in $accessPolicies) {
        Set-AzKeyVaultAccessPolicy -VaultName $TargetVaultName `
                                   -ObjectId $policy.ObjectId `
                                   -PermissionsToKeys $policy.Permissions.Keys `
                                   -PermissionsToSecrets $policy.Permissions.Secrets `
                                   -PermissionsToCertificates $policy.Permissions.Certificates
        Write-Host "Access policy for ObjectId '$($policy.ObjectId)' applied."
    }
}

# --------------------------
# Apply Tags
# --------------------------
if ($tags.Count -eq 0) { Write-Host "No tags to apply." } else {
    Set-AzKeyVault -VaultName $TargetVaultName -Tags $tags
    Write-Host "Tags applied."
}

Write-Host "All JSON data applied to Key Vault '$TargetVaultName'. Done."
