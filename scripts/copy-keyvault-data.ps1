<#
.SYNOPSIS
    Copies secrets, keys, and certificates from source Key Vault to target Key Vault.

.DESCRIPTION
    This script migrates Key Vault data including:
    - Secrets (with values, tags, and attributes)
    - Keys (metadata only - private keys cannot be exported)
    - Certificates (with private keys if exportable)

.PARAMETER SourceVault
    Name of the source Key Vault.

.PARAMETER TargetVault
    Name of the target Key Vault.

.PARAMETER SubscriptionId
    Azure Subscription ID. Uses env:AZURE_SUBSCRIPTION_ID if not provided.

.PARAMETER TenantId
    Azure Tenant ID. Uses env:AZURE_TENANT_ID if not provided.

.PARAMETER ClientId
    Service Principal Client ID. Uses env:AZURE_CLIENT_ID if not provided.

.PARAMETER ClientSecret
    Service Principal Client Secret. Uses env:AZURE_CLIENT_SECRET if not provided.

.PARAMETER CopySecrets
    Copy secrets from source to target. Default: true.

.PARAMETER CopyKeys
    Copy keys from source to target (backup/restore). Default: true.

.PARAMETER CopyCertificates
    Copy certificates from source to target. Default: true.

.PARAMETER OverwriteExisting
    Overwrite existing items in target vault. Default: false.

.EXAMPLE
    .\copy-keyvault-data.ps1 -SourceVault "kv-source" -TargetVault "kv-target"

.EXAMPLE
    .\copy-keyvault-data.ps1 -SourceVault "kv-source" -TargetVault "kv-target" -OverwriteExisting
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceVault,

    [Parameter(Mandatory = $true)]
    [string]$TargetVault,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,

    [Parameter(Mandatory = $false)]
    [string]$TenantId = $env:AZURE_TENANT_ID,

    [Parameter(Mandatory = $false)]
    [string]$ClientId = $env:AZURE_CLIENT_ID,

    [Parameter(Mandatory = $false)]
    [string]$ClientSecret = $env:AZURE_CLIENT_SECRET,

    [Parameter(Mandatory = $false)]
    [bool]$CopySecrets = $true,

    [Parameter(Mandatory = $false)]
    [bool]$CopyKeys = $true,

    [Parameter(Mandatory = $false)]
    [bool]$CopyCertificates = $true,

    [Parameter(Mandatory = $false)]
    [switch]$OverwriteExisting
)

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Results tracking
$results = @{
    Secrets      = @{ Success = 0; Failed = 0; Skipped = 0 }
    Keys         = @{ Success = 0; Failed = 0; Skipped = 0 }
    Certificates = @{ Success = 0; Failed = 0; Skipped = 0 }
}

# --------------------------------------------
# Helper Functions
# --------------------------------------------

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-ItemExistsInTarget {
    param(
        [string]$VaultName,
        [string]$ItemName,
        [string]$ItemType
    )

    try {
        switch ($ItemType) {
            "Secret" {
                $item = Get-AzKeyVaultSecret -VaultName $VaultName -Name $ItemName -ErrorAction SilentlyContinue
            }
            "Key" {
                $item = Get-AzKeyVaultKey -VaultName $VaultName -Name $ItemName -ErrorAction SilentlyContinue
            }
            "Certificate" {
                $item = Get-AzKeyVaultCertificate -VaultName $VaultName -Name $ItemName -ErrorAction SilentlyContinue
            }
        }
        return $null -ne $item
    }
    catch {
        return $false
    }
}

# --------------------------------------------
# Authentication
# --------------------------------------------

Write-Log "Starting Key Vault migration: $SourceVault -> $TargetVault"

# Validate required parameters
if (-not $SubscriptionId -or -not $TenantId -or -not $ClientId -or -not $ClientSecret) {
    Write-Log "Missing authentication parameters. Provide via parameters or environment variables:" "ERROR"
    Write-Log "  AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET" "ERROR"
    exit 1
}

Write-Log "Authenticating to Azure..."
try {
    $secureSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($ClientId, $secureSecret)

    Connect-AzAccount -ServicePrincipal `
        -Tenant $TenantId `
        -Subscription $SubscriptionId `
        -Credential $credential | Out-Null

    Write-Log "Successfully authenticated to Azure" "SUCCESS"
}
catch {
    Write-Log "Failed to authenticate: $_" "ERROR"
    exit 1
}

# Validate Key Vaults exist
Write-Log "Validating Key Vaults..."
try {
    $sourceKv = Get-AzKeyVault -VaultName $SourceVault -ErrorAction Stop
    Write-Log "Source vault found: $($sourceKv.VaultUri)"
}
catch {
    Write-Log "Source Key Vault '$SourceVault' not found or inaccessible" "ERROR"
    exit 1
}

try {
    $targetKv = Get-AzKeyVault -VaultName $TargetVault -ErrorAction Stop
    Write-Log "Target vault found: $($targetKv.VaultUri)"
}
catch {
    Write-Log "Target Key Vault '$TargetVault' not found or inaccessible" "ERROR"
    exit 1
}

# --------------------------------------------
# Copy Secrets
# --------------------------------------------

if ($CopySecrets) {
    Write-Log "========================================"
    Write-Log "COPYING SECRETS"
    Write-Log "========================================"

    try {
        $secrets = Get-AzKeyVaultSecret -VaultName $SourceVault
        Write-Log "Found $($secrets.Count) secrets in source vault"

        foreach ($secretMeta in $secrets) {
            $secretName = $secretMeta.Name
            Write-Log "Processing secret: $secretName"

            try {
                # Check if exists in target
                if (-not $OverwriteExisting -and (Test-ItemExistsInTarget -VaultName $TargetVault -ItemName $secretName -ItemType "Secret")) {
                    Write-Log "  Skipping (already exists in target)" "WARNING"
                    $results.Secrets.Skipped++
                    continue
                }

                # Get full secret with value
                $secret = Get-AzKeyVaultSecret -VaultName $SourceVault -Name $secretName -AsPlainText
                $secretInfo = Get-AzKeyVaultSecret -VaultName $SourceVault -Name $secretName

                # Prepare parameters
                $setParams = @{
                    VaultName   = $TargetVault
                    Name        = $secretName
                    SecretValue = (ConvertTo-SecureString $secret -AsPlainText -Force)
                }

                # Add optional attributes
                if ($secretInfo.ContentType) {
                    $setParams.ContentType = $secretInfo.ContentType
                }
                if ($secretInfo.Attributes.Expires) {
                    $setParams.Expires = $secretInfo.Attributes.Expires
                }
                if ($secretInfo.Attributes.NotBefore) {
                    $setParams.NotBefore = $secretInfo.Attributes.NotBefore
                }
                if ($secretInfo.Tags -and $secretInfo.Tags.Count -gt 0) {
                    $setParams.Tag = $secretInfo.Tags
                }

                # Create secret in target
                Set-AzKeyVaultSecret @setParams | Out-Null

                # Disable if source was disabled
                if (-not $secretInfo.Attributes.Enabled) {
                    Update-AzKeyVaultSecret -VaultName $TargetVault -Name $secretName -Enable $false | Out-Null
                }

                Write-Log "  Copied successfully" "SUCCESS"
                $results.Secrets.Success++
            }
            catch {
                Write-Log "  Failed to copy: $_" "ERROR"
                $results.Secrets.Failed++
            }
        }
    }
    catch {
        Write-Log "Failed to list secrets: $_" "ERROR"
    }
}

# --------------------------------------------
# Copy Keys (using backup/restore)
# --------------------------------------------

if ($CopyKeys) {
    Write-Log "========================================"
    Write-Log "COPYING KEYS"
    Write-Log "========================================"

    try {
        $keys = Get-AzKeyVaultKey -VaultName $SourceVault
        Write-Log "Found $($keys.Count) keys in source vault"

        # Create temp directory for key backups
        $tempDir = Join-Path $env:TEMP "kv-migration-$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        foreach ($keyMeta in $keys) {
            $keyName = $keyMeta.Name
            Write-Log "Processing key: $keyName"

            try {
                # Check if exists in target
                if (-not $OverwriteExisting -and (Test-ItemExistsInTarget -VaultName $TargetVault -ItemName $keyName -ItemType "Key")) {
                    Write-Log "  Skipping (already exists in target)" "WARNING"
                    $results.Keys.Skipped++
                    continue
                }

                # Backup key from source
                $backupFile = Join-Path $tempDir "$keyName.keybackup"
                Backup-AzKeyVaultKey -VaultName $SourceVault -Name $keyName -OutputFile $backupFile -Force | Out-Null

                # Restore key to target
                Restore-AzKeyVaultKey -VaultName $TargetVault -InputFile $backupFile | Out-Null

                # Clean up backup file
                Remove-Item $backupFile -Force -ErrorAction SilentlyContinue

                Write-Log "  Copied successfully (backup/restore)" "SUCCESS"
                $results.Keys.Success++
            }
            catch {
                Write-Log "  Failed to copy: $_" "ERROR"
                $results.Keys.Failed++
            }
        }

        # Clean up temp directory
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "Failed to list keys: $_" "ERROR"
    }
}

# --------------------------------------------
# Copy Certificates (using backup/restore)
# --------------------------------------------

if ($CopyCertificates) {
    Write-Log "========================================"
    Write-Log "COPYING CERTIFICATES"
    Write-Log "========================================"

    try {
        $certificates = Get-AzKeyVaultCertificate -VaultName $SourceVault
        Write-Log "Found $($certificates.Count) certificates in source vault"

        # Create temp directory for certificate backups
        $tempDir = Join-Path $env:TEMP "kv-cert-migration-$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        foreach ($certMeta in $certificates) {
            $certName = $certMeta.Name
            Write-Log "Processing certificate: $certName"

            try {
                # Check if exists in target
                if (-not $OverwriteExisting -and (Test-ItemExistsInTarget -VaultName $TargetVault -ItemName $certName -ItemType "Certificate")) {
                    Write-Log "  Skipping (already exists in target)" "WARNING"
                    $results.Certificates.Skipped++
                    continue
                }

                # Backup certificate from source
                $backupFile = Join-Path $tempDir "$certName.certbackup"
                Backup-AzKeyVaultCertificate -VaultName $SourceVault -Name $certName -OutputFile $backupFile -Force | Out-Null

                # Restore certificate to target
                Restore-AzKeyVaultCertificate -VaultName $TargetVault -InputFile $backupFile | Out-Null

                # Clean up backup file
                Remove-Item $backupFile -Force -ErrorAction SilentlyContinue

                Write-Log "  Copied successfully (backup/restore)" "SUCCESS"
                $results.Certificates.Success++
            }
            catch {
                Write-Log "  Failed to copy: $_" "ERROR"
                $results.Certificates.Failed++
            }
        }

        # Clean up temp directory
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "Failed to list certificates: $_" "ERROR"
    }
}

# --------------------------------------------
# Summary
# --------------------------------------------

Write-Log "========================================"
Write-Log "MIGRATION SUMMARY"
Write-Log "========================================"
Write-Log "Source: $SourceVault"
Write-Log "Target: $TargetVault"
Write-Log ""
Write-Log "Secrets:"
Write-Log "  Success: $($results.Secrets.Success)"
Write-Log "  Failed:  $($results.Secrets.Failed)"
Write-Log "  Skipped: $($results.Secrets.Skipped)"
Write-Log ""
Write-Log "Keys:"
Write-Log "  Success: $($results.Keys.Success)"
Write-Log "  Failed:  $($results.Keys.Failed)"
Write-Log "  Skipped: $($results.Keys.Skipped)"
Write-Log ""
Write-Log "Certificates:"
Write-Log "  Success: $($results.Certificates.Success)"
Write-Log "  Failed:  $($results.Certificates.Failed)"
Write-Log "  Skipped: $($results.Certificates.Skipped)"

$totalFailed = $results.Secrets.Failed + $results.Keys.Failed + $results.Certificates.Failed
if ($totalFailed -gt 0) {
    Write-Log "Migration completed with $totalFailed failures" "WARNING"
    exit 1
}
else {
    Write-Log "Migration completed successfully!" "SUCCESS"
    exit 0
}
