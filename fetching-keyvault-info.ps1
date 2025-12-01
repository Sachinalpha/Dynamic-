# Read from environment variables
$KeyVaultName = $env:KEYVAULT_NAME
$TenantId = $env:AZURE_TENANT_ID
$ClientId = $env:AZURE_CLIENT_ID
$ClientSecret = $env:AZURE_CLIENT_SECRET
$RunId = $env:GITHUB_RUN_ID
if (-not $RunId) { $RunId = (Get-Date -Format "yyyyMMddHHmmss") } # fallback timestamp

$RepoPath = "."
$OutputFolder = "$RepoPath/kv-secrets"

# Create output folder if not exists
if (-not (Test-Path $OutputFolder)) { New-Item -Path $OutputFolder -ItemType Directory }

# Authenticate to Azure using Service Principal
$secureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($ClientId, $secureSecret)
Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $cred

# Fetch all secrets
$secrets = @{}
$secretNames = Get-AzKeyVaultSecret -VaultName $KeyVaultName | Select-Object -ExpandProperty Name

foreach ($name in $secretNames) {
    $secretValue = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $name).SecretValueText
    $secrets[$name] = $secretValue
}

# Save secrets to unique JSON file
if ($secrets.Count -gt 0) {
    $secretFile = "$OutputFolder/secrets_$RunId.json"
    $secrets | ConvertTo-Json -Depth 10 | Out-File -FilePath $secretFile -Encoding UTF8
    Write-Host "Secrets saved to $secretFile"
} else {
    Write-Host "No secrets found in Key Vault $KeyVaultName"
}

# Commit and push
git config --local sachinmadalagi34@gmail.com "github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"

git add $OutputFolder/*.json
git commit -m "Export Key Vault secrets $RunId" || Write-Host "No changes to commit"
git push
