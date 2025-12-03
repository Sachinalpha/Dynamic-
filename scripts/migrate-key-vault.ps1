# Read from environment variables
$KeyVaultName      = $env:KEYVAULT_NAME
$SubscriptionId    = $env:AZURE_SUBSCRIPTION_ID
$TenantId          = $env:AZURE_TENANT_ID
$ClientId          = $env:AZURE_CLIENT_ID
$ClientSecret      = $env:AZURE_CLIENT_SECRET
$PatToken          = $env:PAT 
$RunId             = $env:GITHUB_RUN_ID

if (-not $RunId) {
    $RunId = (Get-Date -Format "yyyyMMddHHmmss")
}

$RepoPath      = "."
$OutputFolder  = "$RepoPath/kv-data"

# Create output folder if not exists
if (-not (Test-Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory
}

# Authenticate to Azure using Service Principal
$secureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($ClientId, $secureSecret)
Connect-AzAccount -ServicePrincipal `
    -Tenant $TenantId `
    -Subscription $SubscriptionId `
    -Credential $cred

# --------------------------
# Fetch Secrets
# --------------------------
$secrets = @{}
$secretNames = Get-AzKeyVaultSecret -VaultName $KeyVaultName | Select-Object -ExpandProperty Name
foreach ($name in $secretNames) {
    $fullSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $name
    $secrets[$name] = @{
        Value   = $fullSecret.SecretValueText
        Enabled = $fullSecret.Attributes.Enabled
        Expires = $fullSecret.Attributes.Expires
        Created = $fullSecret.Attributes.Created
        Tags    = $fullSecret.Tags
    }
}
if ($secrets.Count -gt 0) {
    $secretFile = "$OutputFolder/secrets_$RunId.json"
    $secrets | ConvertTo-Json -Depth 10 | Out-File -FilePath $secretFile -Encoding UTF8
    Write-Host "Secrets saved to $secretFile"
}

# --------------------------
# Fetch Keys
# --------------------------
$keys = @{}
$keyObjects = Get-AzKeyVaultKey -VaultName $KeyVaultName
foreach ($key in $keyObjects) {
    $fullKey = Get-AzKeyVaultKey -VaultName $KeyVaultName -Name $key.Name
    $keys[$key.Name] = @{
        KeyType  = $fullKey.KeyType
        Enabled  = $fullKey.Attributes.Enabled
        Expires  = $fullKey.Attributes.Expires
        Created  = $fullKey.Attributes.Created
        Tags     = $fullKey.Tags
    }
}
if ($keys.Count -gt 0) {
    $keyFile = "$OutputFolder/keys_$RunId.json"
    $keys | ConvertTo-Json -Depth 10 | Out-File -FilePath $keyFile -Encoding UTF8
    Write-Host "Keys saved to $keyFile"
}

# --------------------------
# Fetch Certificates
# --------------------------
$certificates = @{}
$certObjects = Get-AzKeyVaultCertificate -VaultName $KeyVaultName
foreach ($cert in $certObjects) {
    $fullCert = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $cert.Name
    $certificates[$cert.Name] = @{
        Enabled  = $fullCert.Attributes.Enabled
        Expires  = $fullCert.Attributes.Expires
        Created  = $fullCert.Attributes.Created
        Tags     = $fullCert.Tags
    }
}
if ($certificates.Count -gt 0) {
    $certFile = "$OutputFolder/certificates_$RunId.json"
    $certificates | ConvertTo-Json -Depth 10 | Out-File -FilePath $certFile -Encoding UTF8
    Write-Host "Certificates saved to $certFile"
}

# --------------------------
# Fetch Access Policies
# --------------------------
$kv = Get-AzKeyVault -VaultName $KeyVaultName
$accessPolicies = @()
foreach ($policy in $kv.AccessPolicies) {
    $accessPolicies += @{
        TenantId = $policy.TenantId
        ObjectId = $policy.ObjectId
        Permissions = @{
            Keys         = @($policy.Permissions.Keys)
            Secrets      = @($policy.Permissions.Secrets)
            Certificates = @($policy.Permissions.Certificates)
        }
    }
}
if ($accessPolicies.Count -gt 0) {
    $apFile = "$OutputFolder/access_policies_$RunId.json"
    $accessPolicies | ConvertTo-Json -Depth 10 | Out-File -FilePath $apFile -Encoding UTF8
    Write-Host "Access policies saved to $apFile"
}

# --------------------------
# Fetch Key Vault Tags
# --------------------------
$tags = $kv.Tags
if ($tags.Count -gt 0) {
    $tagsFile = "$OutputFolder/tags_$RunId.json"
    $tags | ConvertTo-Json -Depth 10 | Out-File -FilePath $tagsFile -Encoding UTF8
    Write-Host "Tags saved to $tagsFile"
}

# --------------------------
# Commit and Push to GitHub
# --------------------------
git config --global --unset credential.helper
git config --local user.email "github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"

$encodedPat = [System.Web.HttpUtility]::UrlEncode($PatToken)
$remoteUrl = "https://$encodedPat@github.com/Sachinalpha/Dynamic-.git"
git remote set-url origin $remoteUrl

git add $OutputFolder/*.json
git commit -m "Export Key Vault data (secrets, keys, certificates, access policies, tags) $RunId" || Write-Host "No changes to commit"
git push origin HEAD
