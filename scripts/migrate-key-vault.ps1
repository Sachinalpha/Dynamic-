param(
    [Parameter(Mandatory=$true)][string]$AppId,
    [Parameter(Mandatory=$true)][string]$TenantId,
    [Parameter(Mandatory=$true)][string]$Secret,
    [Parameter(Mandatory=$true)][string]$SourceSubscriptionId,
    [Parameter(Mandatory=$true)][string]$SourceVaultName,
    [Parameter(Mandatory=$true)][string]$TargetSubscriptionId,
    [Parameter(Mandatory=$true)][string]$TargetVaultName
)

# ---------------------------------------
# Step 1: Login
# ---------------------------------------
try {
    $secureSecret = ConvertTo-SecureString $Secret -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($AppId, $secureSecret)
    Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $cred -ErrorAction Stop
    Write-Host "✔ Logged in successfully as SP: $AppId"
} catch {
    Write-Warning "Azure login failed: $_"
    return
}

# ---------------------------------------
# Step 2: Locate Source & Target Key Vaults
# ---------------------------------------
try {
    Set-AzContext -Subscription $SourceSubscriptionId
    $sourceKV = Get-AzKeyVault -VaultName $SourceVaultName -ErrorAction Stop
    Write-Host "✔ Source Key Vault found: $SourceVaultName"
} catch {
    Write-Warning "Source Key Vault not found: $SourceVaultName"
    return
}

try {
    Set-AzContext -Subscription $TargetSubscriptionId
    $targetKV = Get-AzKeyVault -VaultName $TargetVaultName -ErrorAction Stop
    Write-Host "✔ Target Key Vault found: $TargetVaultName"
} catch {
    Write-Warning "Target Key Vault not found: $TargetVaultName"
    return
}

# ---------------------------------------
# Step 3: Copy VNet/Subnet rules
# ---------------------------------------
try {
    $vnetRules = $sourceKV.NetworkAcls.VirtualNetworkRules
    if ($vnetRules) {
        foreach ($rule in $vnetRules) {
            try {
                Add-AzKeyVaultNetworkRule -VaultName $TargetVaultName -SubnetId $rule.Id
                Write-Host "✔ VNet/Subnet rule copied: $($rule.Id)"
            } catch {
                Write-Warning "Could not copy VNet/Subnet rule $($rule.Id): $_"
            }
        }
    } else { Write-Warning "No VNet/Subnet rules found." }
} catch {
    Write-Warning "Error retrieving VNet/Subnet rules: $_"
}

# ---------------------------------------
# Step 4: Copy Secrets
# ---------------------------------------
try {
    Set-AzContext -Subscription $SourceSubscriptionId
    $secrets = Get-AzKeyVaultSecret -VaultName $SourceVaultName -ErrorAction SilentlyContinue
    if ($secrets) {
        Set-AzContext -Subscription $TargetSubscriptionId
        foreach ($s in $secrets) {
            try {
                $value = (Get-AzKeyVaultSecret -VaultName $SourceVaultName -Name $s.Name).SecretValueText
                Set-AzKeyVaultSecret -VaultName $TargetVaultName -Name $s.Name -SecretValue (ConvertTo-SecureString $value -AsPlainText -Force)
                Write-Host "✔ Secret copied: $($s.Name)"
            } catch {
                Write-Warning "Could not copy secret $($s.Name): $_"
            }
        }
    } else { Write-Warning "No secrets found to copy." }
} catch { Write-Warning "Error retrieving secrets: $_" }

# ---------------------------------------
# Step 5: Copy Keys
# ---------------------------------------
try {
    Set-AzContext -Subscription $SourceSubscriptionId
    $keys = Get-AzKeyVaultKey -VaultName $SourceVaultName -ErrorAction SilentlyContinue
    if ($keys) {
        foreach ($k in $keys) {
            Write-Warning "Key $($k.Name) exists -> Manual copy may be required if non-exportable"
        }
    } else { Write-Warning "No keys found to copy." }
} catch { Write-Warning "Error retrieving keys: $_" }

# ---------------------------------------
# Step 6: Copy Certificates
# ---------------------------------------
try {
    Set-AzContext -Subscription $SourceSubscriptionId
    $certs = Get-AzKeyVaultCertificate -VaultName $SourceVaultName -ErrorAction SilentlyContinue
    if ($certs) {
        foreach ($c in $certs) {
            Write-Warning "Certificate $($c.Name) exists -> Manual copy may be required if non-exportable"
        }
    } else { Write-Warning "No certificates found to copy." }
} catch { Write-Warning "Error retrieving certificates: $_" }

# ---------------------------------------
# Step 7: Copy Access Policies
# ---------------------------------------
try {
    Set-AzContext -Subscription $SourceSubscriptionId
    $sourcePolicies = Get-AzKeyVaultAccessPolicy -VaultName $SourceVaultName -ErrorAction SilentlyContinue
    if ($sourcePolicies) {
        Set-AzContext -Subscription $TargetSubscriptionId
        foreach ($p in $sourcePolicies) {
            try {
                Set-AzKeyVaultAccessPolicy -VaultName $TargetVaultName -ObjectId $p.ObjectId -PermissionsToSecrets $p.PermissionsToSecrets -PermissionsToKeys $p.PermissionsToKeys -PermissionsToCertificates $p.PermissionsToCertificates
                Write-Host "✔ Access policy copied: $($p.ObjectId)"
            } catch {
                Write-Warning "Could not copy access policy for $($p.ObjectId): $_"
            }
        }
    } else { Write-Warning "No access policies found." }
} catch { Write-Warning "Error retrieving access policies: $_" }

# ---------------------------------------
# Step 8: Copy Tags
# ---------------------------------------
try {
    $sourceTags = $sourceKV.Tags
    if ($sourceTags) {
        $targetTags = $targetKV.Tags
        if (-not $targetTags) { $targetTags = @{} }
        $mergedTags = @{}
        foreach ($k in $targetTags.Keys) { $mergedTags[$k] = $targetTags[$k] }
        foreach ($k in $sourceTags.Keys) { $mergedTags[$k] = $sourceTags[$k] }
        Set-AzResource -ResourceId $targetKV.ResourceId -Tag $mergedTags -Force
        Write-Host "✔ Tags merged/copied successfully."
    } else { Write-Warning "No tags found." }
} catch { Write-Warning "Error copying tags: $_" }

Write-Host "`n=== Migration Attempt Completed for Key Vault: $TargetVaultName ==="
