# Read from environment variables
$KeyVaultName = $env:KEYVAULT_NAME
$TenantId = $env:AZURE_TENANT_ID
$ClientId = $env:AZURE_CLIENT_ID
$ClientSecret = $env:AZURE_CLIENT_SECRET
$PatToken = $env:PAT 
$RunId = $env:GITHUB_RUN_ID

if (-not $RunId) {
    $RunId = (Get-Date -Format "yyyyMMddHHmmss")
}

$RepoPath = "."
$OutputFolder = "$RepoPath/kv-data"

# Create output folder if not exists
if (-not (Test-Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory
}

# Authenticate to Azure using Service Principal
$secureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($ClientId, $secureSecret)
Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $cred

# --------------------------
# Fetch Secrets
# --------------------------
$secrets = @{}
$secretNames = Get-AzKeyVaultSecret -VaultName $KeyVaultName | Select-Object -ExpandProperty Name

foreach ($name in $secretNames) {
    $secretValue = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $name).SecretValueText
    $secrets[$name] = $secretValue
}

if ($secrets.Count -gt 0) {
    $secretFile = "$OutputFolder/secrets_$RunId.json"
    $secrets | ConvertTo-Json -Depth 10 | Out-File -FilePath $secretFile -Encoding UTF8
    Write-Host "Secrets saved to $secretFile"
} else {
    Write-Host "No secrets found in Key Vault $KeyVaultName"
}

# --------------------------
# Fetch Keys
# --------------------------
$keys = @{}
$keyObjects = Get-AzKeyVaultKey -VaultName $KeyVaultName

foreach ($key in $keyObjects) {
    $keys[$key.Name] = @{
        KeyType = $key.KeyType
        Enabled = $key.Attributes.Enabled
        Expires = $key.Attributes.Expires
        Created = $key.Attributes.Created
        Tags = $key.Tags
    }
}

if ($keys.Count -gt 0) {
    $keyFile = "$OutputFolder/keys_$RunId.json"
    $keys | ConvertTo-Json -Depth 10 | Out-File -FilePath $keyFile -Encoding UTF8
    Write-Host "Keys saved to $keyFile"
} else {
    Write-Host "No keys found in Key Vault $KeyVaultName"
}

# --------------------------
# Fetch Key Vault Tags
# --------------------------
$kv = Get-AzKeyVault -VaultName $KeyVaultName
$tags = $kv.Tags

if ($tags.Count -gt 0) {
    $tagsFile = "$OutputFolder/tags_$RunId.json"
    $tags | ConvertTo-Json -Depth 10 | Out-File -FilePath $tagsFile -Encoding UTF8
    Write-Host "Tags saved to $tagsFile"
} else {
    Write-Host "No tags found in Key Vault $KeyVaultName"
}

# --------------------------
# Commit and Push to GitHub
# --------------------------
# Disable GitHub credential helper
git config --global --unset credential.helper

# Set Git identity
git config --local user.email "github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"

# Encode PAT and update remote
$encodedPat = [System.Web.HttpUtility]::UrlEncode($PatToken)
$remoteUrl = "https://$encodedPat@github.com/Sachinalpha/Dynamic-.git"
git remote set-url origin $remoteUrl

# Commit and push
git add $OutputFolder/*.json
git commit -m "Export Key Vault data (secrets, keys, tags) $RunId" || Write-Host "No changes to commit"
git push origin HEAD
