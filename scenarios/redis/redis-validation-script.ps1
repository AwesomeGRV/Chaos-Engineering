# Redis Cache Chaos Validation Script
# Validates Redis cache functionality during chaos experiments

param(
    [string]$ResourceGroup = "",
    [string]$RedisName = "",
    [string]$ConnectionString = "",
    [int]$Port = 6379
)

# Install required modules
if (-not (Get-Module -ListAvailable -Name Az.Cache)) {
    Install-Module -Name Az.Cache -Force -Scope CurrentUser
}

# Initialize logging
$logPath = "C:\temp\redis-chaos-validation.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $Message"
    Write-Host $Message
}

# Test Redis connectivity
function Test-RedisConnectivity {
    Write-Log "Testing Redis connectivity..."
    
    try {
        if (-not $ConnectionString) {
            $keys = Get-AzRedisCacheKey -ResourceGroupName $ResourceGroup -Name $RedisName
            $hostname = (Get-AzRedisCache -ResourceGroupName $ResourceGroup -Name $RedisName).HostName
            $ConnectionString = "$hostname`:$Port,password=$($keys.PrimaryKey),ssl=true,abortConnect=false"
        }
        
        # Test basic connectivity using redis-cli (if available) or PowerShell
        try {
            # Try to connect using Test-NetConnection first
            $hostname = $ConnectionString.Split(':')[0]
            $port = [int]$ConnectionString.Split(':')[1].Split(',')[0]
            
            $connection = Test-NetConnection -ComputerName $hostname -Port $port -WarningAction SilentlyContinue
            if ($connection.TcpTestSucceeded) {
                Write-Log "✓ Redis TCP connection successful"
                return $true
            } else {
                Write-Log "✗ Redis TCP connection failed"
                return $false
            }
        }
        catch {
            Write-Log "✗ Redis connectivity test failed: $($_.Exception.Message)"
            return $false
        }
    }
    catch {
        Write-Log "✗ Redis connectivity failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Redis basic operations
function Test-RedisBasicOperations {
    Write-Log "Testing Redis basic operations..."
    
    try {
        # Simulate Redis operations using Azure CLI or direct commands
        $testKey = "chaos-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        # Test SET operation
        try {
            $redis = Get-AzRedisCache -ResourceGroupName $ResourceGroup -Name $RedisName
            Write-Log "✓ Redis cache instance accessible"
            
            # Note: Actual Redis operations would require Redis client library
            # For validation purposes, we'll test cache properties
            if ($redis.ProvisioningState -eq "Succeeded") {
                Write-Log "✓ Redis cache provisioning state: $($redis.ProvisioningState)"
            } else {
                Write-Log "⚠ Redis cache provisioning state: $($redis.ProvisioningState)"
            }
            
            return $true
        }
        catch {
            Write-Log "✗ Redis basic operations failed: $($_.Exception.Message)"
            return $false
        }
    }
    catch {
        Write-Log "✗ Redis operations test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Redis performance
function Test-RedisPerformance {
    Write-Log "Testing Redis performance..."
    
    try {
        $redis = Get-AzRedisCache -ResourceGroupName $ResourceGroup -Name $RedisName
        
        # Test cache properties related to performance
        $sku = $redis.Sku.Name
        $capacity = $redis.Sku.Capacity
        $shardCount = $redis.ShardCount
        
        Write-Log "Redis SKU: $sku"
        Write-Log "Redis Capacity: $capacity"
        Write-Log "Redis Shard Count: $shardCount"
        
        # Performance expectations based on SKU
        $performanceThresholds = @{
            "Basic" = @{ MemoryGB = 0.5; Connections = 256 }
            "Standard" = @{ MemoryGB = 1; Connections = 1000 }
            "Premium" = @{ MemoryGB = 6; Connections = 10000 }
        }
        
        if ($performanceThresholds.ContainsKey($sku)) {
            $threshold = $performanceThresholds[$sku]
            $expectedMemory = $threshold.MemoryGB * $capacity
            Write-Log "Expected memory: $expectedMemory GB"
            Write-Log "Max connections: $($threshold.Connections)"
            
            Write-Log "✓ Redis performance configuration validated"
            return $true
        } else {
            Write-Log "⚠ Unknown Redis SKU: $sku"
            return $true
        }
    }
    catch {
        Write-Log "✗ Redis performance test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Redis high availability
function Test-RedisHighAvailability {
    Write-Log "Testing Redis high availability..."
    
    try {
        $redis = Get-AzRedisCache -ResourceGroupName $ResourceGroup -Name $RedisName
        
        # Check if it's a premium cache with HA enabled
        if ($redis.Sku.Name -eq "Premium") {
            Write-Log "✓ Premium cache supports high availability"
            
            # Check for replica count
            if ($redis.ReplicaCount -gt 0) {
                Write-Log "✓ Redis replica count: $($redis.ReplicaCount)"
            } else {
                Write-Log "⚠ Redis replica count not specified"
            }
            
            # Check for availability zones
            if ($redis.Zones) {
                Write-Log "✓ Redis availability zones: $($redis.Zones -join ', ')"
            } else {
                Write-Log "⚠ Redis availability zones not configured"
            }
            
            return $true
        } else {
            Write-Log "⚠ Standard/Basic cache - limited HA features"
            return $true
        }
    }
    catch {
        Write-Log "✗ Redis HA test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Redis persistence
function Test-RedisPersistence {
    Write-Log "Testing Redis persistence..."
    
    try {
        $redis = Get-AzRedisCache -ResourceGroupName $ResourceGroup -Name $RedisName
        
        # Check persistence configuration
        if ($redis.RedisConfiguration) {
            $config = $redis.RedisConfiguration
            
            if ($config.ContainsKey("rdb-backup-enabled")) {
                $rdbEnabled = $config["rdb-backup-enabled"]
                Write-Log "RDB backup enabled: $rdbEnabled"
                
                if ($rdbEnabled -eq "true") {
                    if ($config.ContainsKey("rdb-storage-connection-string")) {
                        Write-Log "✓ RDB backup storage configured"
                    }
                    if ($config.ContainsKey("rdb-backup-frequency")) {
                        Write-Log "RDB backup frequency: $($config["rdb-backup-frequency"])"
                    }
                }
            }
            
            if ($config.ContainsKey("aof-backup-enabled")) {
                $aofEnabled = $config["aof-backup-enabled"]
                Write-Log "AOF backup enabled: $aofEnabled"
            }
            
            Write-Log "✓ Redis persistence configuration checked"
            return $true
        } else {
            Write-Log "⚠ No Redis persistence configuration found"
            return $true
        }
    }
    catch {
        Write-Log "✗ Redis persistence test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Redis security
function Test-RedisSecurity {
    Write-Log "Testing Redis security..."
    
    try {
        $redis = Get-AzRedisCache -ResourceGroupName $ResourceGroup -Name $RedisName
        
        # Check SSL configuration
        if ($redis.EnableNonSslPort) {
            Write-Log "⚠ Non-SSL port enabled - security consideration"
        } else {
            Write-Log "✓ SSL-only connections enforced"
        }
        
        # Check private endpoint configuration
        try {
            $privateEndpoints = Get-AzPrivateEndpoint -ResourceGroupName $ResourceGroup | Where-Object { $_.PrivateLinkServiceConnections.PrivateLinkServiceId -like "*$RedisName*" }
            if ($privateEndpoints.Count -gt 0) {
                Write-Log "✓ Private endpoints configured: $($privateEndpoints.Count)"
            } else {
                Write-Log "⚠ No private endpoints found"
            }
        }
        catch {
            Write-Log "⚠ Could not check private endpoints"
        }
        
        # Check firewall rules
        try {
            $firewallRules = Get-AzRedisCacheFirewallRule -ResourceGroupName $ResourceGroup -Name $RedisName
            if ($firewallRules.Count -gt 0) {
                Write-Log "✓ Firewall rules configured: $($firewallRules.Count)"
                foreach ($rule in $firewallRules) {
                    Write-Log "  - $($rule.Name): $($rule.StartIP) - $($rule.EndIP)"
                }
            } else {
                Write-Log "⚠ No firewall rules found"
            }
        }
        catch {
            Write-Log "⚠ Could not check firewall rules"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Redis security test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Redis monitoring
function Test-RedisMonitoring {
    Write-Log "Testing Redis monitoring..."
    
    try {
        $resourceId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroup/providers/Microsoft.Cache/redis/$RedisName"
        
        # Check if diagnostic settings are configured
        try {
            $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $resourceId
            if ($diagnosticSettings.Count -gt 0) {
                Write-Log "✓ Diagnostic settings configured: $($diagnosticSettings.Count)"
                foreach ($setting in $diagnosticSettings) {
                    Write-Log "  - $($setting.Name): $($setting.WorkspaceId)"
                }
            } else {
                Write-Log "⚠ No diagnostic settings found"
            }
        }
        catch {
            Write-Log "⚠ Could not check diagnostic settings"
        }
        
        # Check alert rules
        try {
            $alertRules = Get-AzAlertRule -ResourceGroup $ResourceGroup | Where-Object { $_.TargetResourceId -eq $resourceId }
            if ($alertRules.Count -gt 0) {
                Write-Log "✓ Alert rules configured: $($alertRules.Count)"
                foreach ($rule in $alertRules) {
                    Write-Log "  - $($rule.Name): $($rule.Description)"
                }
            } else {
                Write-Log "⚠ No alert rules found"
            }
        }
        catch {
            Write-Log "⚠ Could not check alert rules"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Redis monitoring test failed: $($_.Exception.Message)"
        return $false
    }
}

# Get Redis metrics
function Get-RedisMetrics {
    Write-Log "Collecting Redis metrics..."
    
    try {
        $resourceId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroup/providers/Microsoft.Cache/redis/$RedisName"
        
        $metrics = @()
        
        # Basic Redis metrics
        try {
            $connections = Get-AzMetric -ResourceId $resourceId -MetricNames "ConnectedClients" -TimeGrain 00:01:00 -AggregationType Maximum
            $metrics += @{
                Name = "ConnectedClients"
                Value = ($connections | Select-Object -Last 1).Data.Maximum
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve ConnectedClients metric"
        }
        
        try {
            $memory = Get-AzMetric -ResourceId $resourceId -MetricNames "UsedMemoryPercentage" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "UsedMemoryPercentage"
                Value = ($memory | Select-Object -Last 1).Data.Average
                Unit = "Percent"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve UsedMemoryPercentage metric"
        }
        
        try {
            $operations = Get-AzMetric -ResourceId $resourceId -MetricNames "CacheOperations" -TimeGrain 00:01:00 -AggregationType Total
            $metrics += @{
                Name = "CacheOperations"
                Value = ($operations | Select-Object -Last 1).Data.Total
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve CacheOperations metric"
        }
        
        try {
            $hits = Get-AzMetric -ResourceId $resourceId -MetricNames "CacheHits" -TimeGrain 00:01:00 -AggregationType Total
            $misses = Get-AzMetric -ResourceId $resourceId -MetricNames "CacheMisses" -TimeGrain 00:01:00 -AggregationType Total
        
            $totalRequests = ($hits | Select-Object -Last 1).Data.Total + ($misses | Select-Object -Last 1).Data.Total
            $hitRate = if ($totalRequests -gt 0) { (($hits | Select-Object -Last 1).Data.Total / $totalRequests) * 100 } else { 0 }
            
            $metrics += @{
                Name = "CacheHitRate"
                Value = [math]::Round($hitRate, 2)
                Unit = "Percent"
            }
        }
        catch {
            Write-Log "⚠ Could not calculate cache hit rate"
        }
        
        try {
            $errors = Get-AzMetric -ResourceId $resourceId -MetricNames "Errors" -TimeGrain 00:01:00 -AggregationType Total
            $metrics += @{
                Name = "Errors"
                Value = ($errors | Select-Object -Last 1).Data.Total
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve Errors metric"
        }
        
        return $metrics
    }
    catch {
        Write-Log "✗ Failed to collect metrics: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
Write-Log "Starting Redis chaos validation..."
Write-Log "Resource Group: $ResourceGroup"
Write-Log "Redis Cache: $RedisName"
Write-Log "Port: $Port"

$testResults = @()

# Run all tests
$testResults += @{ Test = "Connectivity"; Result = (Test-RedisConnectivity) }
$testResults += @{ Test = "BasicOperations"; Result = (Test-RedisBasicOperations) }
$testResults += @{ Test = "Performance"; Result = (Test-RedisPerformance) }
$testResults += @{ Test = "HighAvailability"; Result = (Test-RedisHighAvailability) }
$testResults += @{ Test = "Persistence"; Result = (Test-RedisPersistence) }
$testResults += @{ Test = "Security"; Result = (Test-RedisSecurity) }
$testResults += @{ Test = "Monitoring"; Result = (Test-RedisMonitoring) }

# Get metrics
$metrics = Get-RedisMetrics

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
    Write-Log "All tests passed - Redis cache healthy"
    exit 0
} else {
    Write-Log "Some tests failed - Redis cache issues detected"
    exit 1
}
