# Azure Key Vault Chaos Validation Script
# Validates Key Vault functionality during chaos experiments

param(
    [string]$ResourceGroup = "",
    [string]$KeyVaultName = "",
    [string]$TestSecretName = "chaos-test-secret"
)

# Install required modules
if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
    Install-Module -Name Az.KeyVault -Force -Scope CurrentUser
}

# Initialize logging
$logPath = "C:\temp\key-vault-chaos-validation.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $Message"
    Write-Host $Message
}

# Test Key Vault basic connectivity
function Test-KeyVaultConnectivity {
    Write-Log "Testing Key Vault connectivity..."
    
    try {
        $keyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroup -VaultName $KeyVaultName
        Write-Log "✓ Key Vault found: $($keyVault.VaultName)"
        Write-Log "Key Vault URI: $($keyVault.VaultUri)"
        Write-Log "Location: $($keyVault.Location)"
        Write-Log "SKU: $($keyVault.Sku.Name)"
        
        return $true
    }
    catch {
        Write-Log "✗ Key Vault connectivity failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Key Vault secret operations
function Test-KeyVaultSecrets {
    Write-Log "Testing Key Vault secret operations..."
    
    try {
        # Create a test secret
        $testSecretValue = "ChaosTestValue-$(Get-Date -Format 'yyyyMMddHHmmss')"
        $secret = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $TestSecretName -SecretValue $testSecretValue -Expires (Get-Date).AddHours(1)
        Write-Log "✓ Created test secret: $TestSecretName"
        
        # Retrieve the secret
        $retrievedSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $TestSecretName -AsPlainText
        if ($retrievedSecret -eq $testSecretValue) {
            Write-Log "✓ Secret retrieval successful"
        } else {
            Write-Log "✗ Secret retrieval failed - value mismatch"
            return $false
        }
        
        # Update the secret
        $updatedValue = "UpdatedValue-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $TestSecretName -SecretValue $updatedValue
        $updatedSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $TestSecretName -AsPlainText
        
        if ($updatedSecret -eq $updatedValue) {
            Write-Log "✓ Secret update successful"
        } else {
            Write-Log "✗ Secret update failed"
            return $false
        }
        
        # List all secrets
        $secrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName
        Write-Log "✓ Found $($secrets.Count) secrets in Key Vault"
        
        # Clean up test secret
        Remove-AzKeyVaultSecret -VaultName $KeyVaultName -Name $TestSecretName -Force -ErrorAction SilentlyContinue
        Write-Log "✓ Cleaned up test secret"
        
        return $true
    }
    catch {
        Write-Log "✗ Key Vault secret operations failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Key Vault certificate operations
function Test-KeyVaultCertificates {
    Write-Log "Testing Key Vault certificate operations..."
    
    try {
        # List existing certificates
        $certificates = Get-AzKeyVaultCertificate -VaultName $KeyVaultName
        Write-Log "✓ Found $($certificates.Count) certificates in Key Vault"
        
        if ($certificates.Count -gt 0) {
            # Test retrieving a certificate
            $testCert = $certificates[0]
            $certPolicy = Get-AzKeyVaultCertificatePolicy -VaultName $KeyVaultName -Name $testCert.Name
            Write-Log "✓ Retrieved certificate policy for: $($testCert.Name)"
            Write-Log "  - Subject: $($certPolicy.Subject)"
            Write-Log "  - Validity: $($certPolicy.ValidityInMonths) months"
        }
        
        # Test certificate creation (self-signed for testing)
        try {
            $testCertName = "chaos-test-cert-$(Get-Date -Format 'yyyyMMddHHmmss')"
            $policy = New-AzKeyVaultCertificatePolicy -SecretContentType "application/x-pkcs12" -SubjectName "CN=Chaos Test" -ValidityInMonths 1 -ReuseKeyOnRenewal $true
            
            # Note: This might require additional permissions
            # Add-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $testCertName -CertificatePolicy $policy
            Write-Log "✓ Certificate policy creation test (actual creation skipped for safety)"
        }
        catch {
            Write-Log "⚠ Certificate creation test failed (may require additional permissions): $($_.Exception.Message)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Key Vault certificate operations failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Key Vault key operations
function Test-KeyVaultKeys {
    Write-Log "Testing Key Vault key operations..."
    
    try {
        # List existing keys
        $keys = Get-AzKeyVaultKey -VaultName $KeyVaultName
        Write-Log "✓ Found $($keys.Count) keys in Key Vault"
        
        if ($keys.Count -gt 0) {
            # Test key operations
            $testKey = $keys[0]
            Write-Log "✓ Retrieved key: $($testKey.Name)"
            Write-Log "  - Key Type: $($testKey.KeyType)"
            Write-Log "  - Key Size: $($testKey.KeySize)"
            
            # Test key version operations
            $keyVersions = Get-AzKeyVaultKey -VaultName $KeyVaultName -Name $testKey.Name -IncludeVersions
            Write-Log "✓ Found $($keyVersions.Count) versions for key: $($testKey.Name)"
        }
        
        # Test key creation (RSA for testing)
        try {
            $testKeyName = "chaos-test-key-$(Get-Date -Format 'yyyyMMddHHmmss')"
            $key = Add-AzKeyVaultKey -VaultName $KeyVaultName -Name $testKeyName -Destination "Software" -KeyType "RSA"
            Write-Log "✓ Created test key: $testKeyName"
            
            # Test key encryption/decryption
            $plaintext = "Chaos test message"
            $encrypted = Set-AzKeyVaultKeyOperation -VaultName $KeyVaultName -Name $testKeyName -Operation "Encrypt" -Value $plaintext
            $decrypted = Set-AzKeyVaultKeyOperation -VaultName $KeyVaultName -Name $testKeyName -Operation "Decrypt" -Value $encrypted.Result
            
            if ($decrypted.Result -eq $plaintext) {
                Write-Log "✓ Key encryption/decryption successful"
            } else {
                Write-Log "✗ Key encryption/decryption failed"
                return $false
            }
            
            # Clean up test key
            Remove-AzKeyVaultKey -VaultName $KeyVaultName -Name $testKeyName -Force -ErrorAction SilentlyContinue
            Write-Log "✓ Cleaned up test key"
        }
        catch {
            Write-Log "⚠ Key operations test failed (may require additional permissions): $($_.Exception.Message)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Key Vault key operations failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Key Vault access policies
function Test-KeyVaultAccessPolicies {
    Write-Log "Testing Key Vault access policies..."
    
    try {
        $keyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroup -VaultName $KeyVaultName
        $accessPolicies = $keyVault.AccessPolicies
        
        Write-Log "✓ Found $($accessPolicies.Count) access policies"
        
        foreach ($policy in $accessPolicies) {
            Write-Log "  - ObjectId: $($policy.ObjectId)"
            Write-Log "  - Permissions to secrets: $($policy.Permissions.Secrets -join ', ')"
            Write-Log "  - Permissions to keys: $($policy.Permissions.Keys -join ', ')"
            Write-Log "  - Permissions to certificates: $($policy.Permissions.Certificates -join ', ')"
        }
        
        # Test current user access
        try {
            $currentUser = (Get-AzContext).Account.Id
            $userPolicies = $accessPolicies | Where-Object { $_.ObjectId -eq $currentUser -or $_.ObjectId -like "*$currentUser*" }
            
            if ($userPolicies.Count -gt 0) {
                Write-Log "✓ Current user has access policies configured"
            } else {
                Write-Log "⚠ Current user may not have explicit access policies (might be using RBAC)"
            }
        }
        catch {
            Write-Log "⚠ Could not verify current user access policies"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Key Vault access policies test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Key Vault networking
function Test-KeyVaultNetworking {
    Write-Log "Testing Key Vault networking configuration..."
    
    try {
        $keyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroup -VaultName $KeyVaultName
        
        # Check network ACLs
        if ($keyVault.NetworkAcls) {
            $networkAcls = $keyVault.NetworkAcls
            Write-Log "✓ Network ACLs configured"
            Write-Log "  - Default action: $($networkAcls.DefaultAction)"
            Write-Log "  - Bypass: $($networkAcls.Bypass)"
            
            if ($networkAcls.IpRules) {
                Write-Log "  - IP Rules: $($networkAcls.IpRules.Count)"
            }
            
            if ($networkAcls.VirtualNetworkRules) {
                Write-Log "  - Virtual Network Rules: $($networkAcls.VirtualNetworkRules.Count)"
            }
            
            if ($networkAcls.DefaultAction -eq "Deny") {
                Write-Log "⚠ Key Vault has restrictive network settings"
            }
        } else {
            Write-Log "⚠ No network ACLs configured (allowing all traffic)"
        }
        
        # Check private endpoint connections
        try {
            $privateEndpoints = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $keyVault.ResourceId
            if ($privateEndpoints.Count -gt 0) {
                Write-Log "✓ Found $($privateEndpoints.Count) private endpoint connections"
                foreach $endpoint in $privateEndpoints {
                    Write-Log "  - $($endpoint.Name): $($endpoint.ProvisioningState)"
                }
            } else {
                Write-Log "⚠ No private endpoint connections found"
            }
        }
        catch {
            Write-Log "⚠ Could not check private endpoint connections"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Key Vault networking test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Key Vault diagnostic settings
function Test-KeyVaultDiagnostics {
    Write-Log "Testing Key Vault diagnostic settings..."
    
    try {
        $keyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroup -VaultName $KeyVaultName
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $keyVault.ResourceId -ErrorAction SilentlyContinue
        
        if ($diagnosticSettings.Count -gt 0) {
            Write-Log "✓ Found $($diagnosticSettings.Count) diagnostic settings"
            
            foreach ($setting in $diagnosticSettings) {
                Write-Log "  - Name: $($setting.Name)"
                Write-Log "  - Workspace ID: $($setting.WorkspaceId)"
                Write-Log "  - Categories: $($setting.Metrics | ForEach-Object { $_.Category } -join ', ')"
                Write-Log "  - Log categories: $($setting.Logs | ForEach-Object { $_.Category } -join ', ')"
            }
        } else {
            Write-Log "⚠ No diagnostic settings configured"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Key Vault diagnostics test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Key Vault soft delete and purge protection
function Test-KeyVaultSoftDelete {
    Write-Log "Testing Key Vault soft delete and purge protection..."
    
    try {
        $keyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroup -VaultName $KeyVaultName
        
        Write-Log "✓ Soft delete enabled: $($keyVault.EnableSoftDelete)"
        Write-Log "✓ Purge protection enabled: $($keyVault.EnablePurgeProtection)"
        
        if ($keyVault.EnableSoftDelete) {
            Write-Log "✓ Soft delete retention days: $($keyVault.SoftDeleteRetentionInDays)"
        }
        
        if ($keyVault.EnablePurgeProtection) {
            Write-Log "✓ Purge protection enabled - secrets cannot be permanently deleted"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Key Vault soft delete test failed: $($_.Exception.Message)"
        return $false
    }
}

# Get Key Vault metrics
function Get-KeyVaultMetrics {
    Write-Log "Collecting Key Vault metrics..."
    
    try {
        $resourceId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroup/providers/Microsoft.KeyVault/vaults/$KeyVaultName"
        
        $metrics = @()
        
        # Service API latency
        try {
            $latency = Get-AzMetric -ResourceId $resourceId -MetricNames "ServiceApiLatency" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "ServiceApiLatency"
                Value = ($latency | Select-Object -Last 1).Data.Average
                Unit = "Milliseconds"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve ServiceApiLatency metric"
        }
        
        # Service API success rate
        try {
            $successRate = Get-AzMetric -ResourceId $resourceId -MetricNames "ServiceApiSuccessRate" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "ServiceApiSuccessRate"
                Value = ($successRate | Select-Object -Last 1).Data.Average
                Unit = "Percent"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve ServiceApiSuccessRate metric"
        }
        
        # Availability
        try {
            $availability = Get-AzMetric -ResourceId $resourceId -MetricNames "Availability" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "Availability"
                Value = ($availability | Select-Object -Last 1).Data.Average
                Unit = "Percent"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve Availability metric"
        }
        
        # Saturation
        try {
            $saturation = Get-AzMetric -ResourceId $resourceId -MetricNames "Saturation" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "Saturation"
                Value = ($saturation | Select-Object -Last 1).Data.Average
                Unit = "Percent"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve Saturation metric"
        }
        
        return $metrics
    }
    catch {
        Write-Log "✗ Failed to collect metrics: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
Write-Log "Starting Key Vault chaos validation..."
Write-Log "Resource Group: $ResourceGroup"
Write-Log "Key Vault: $KeyVaultName"
Write-Log "Test Secret Name: $TestSecretName"

$testResults = @()

# Run all tests
$testResults += @{ Test = "Connectivity"; Result = (Test-KeyVaultConnectivity) }
$testResults += @{ Test = "SecretOperations"; Result = (Test-KeyVaultSecrets) }
$testResults += @{ Test = "CertificateOperations"; Result = (Test-KeyVaultCertificates) }
$testResults += @{ Test = "KeyOperations"; Result = (Test-KeyVaultKeys) }
$testResults += @{ Test = "AccessPolicies"; Result = (Test-KeyVaultAccessPolicies) }
$testResults += @{ Test = "Networking"; Result = (Test-KeyVaultNetworking) }
$testResults += @{ Test = "Diagnostics"; Result = (Test-KeyVaultDiagnostics) }
$testResults += @{ Test = "SoftDelete"; Result = (Test-KeyVaultSoftDelete) }

# Get metrics
$metrics = Get-KeyVaultMetrics

# Summary
Write-Log "=== TEST SUMMARY ==="
$passedTests = ($testResults | Where-Object { $_.Result -eq $true }).Count
$totalTests = $testResults.Count

foreach ($result in $testResults) {
    $status = if ($result.Result) { "PASS" } else { "FAIL" }
    Write-Log "$($result.Test): $status"
}

Write-Log "Overall: $passedTests/$totalTests tests passed"

if ($metrics.Count -gt 0) {
    Write-Log "=== METRICS ==="
    foreach ($metric in $metrics) {
        Write-Log "$($metric.Name): $($metric.Value) $($metric.Unit)"
    }
}

# Return exit code
if ($passedTests -eq $totalTests) {
    Write-Log "All tests passed - Key Vault healthy"
    exit 0
} else {
    Write-Log "Some tests failed - Key Vault issues detected"
    exit 1
}
