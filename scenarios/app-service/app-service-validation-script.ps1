# App Service Chaos Validation Script
# Validates App Service health and functionality during chaos experiments

param(
    [string]$ResourceGroup = "",
    [string]$AppServiceName = "",
    [string]$SlotName = "production",
    [string]$ProbeUrl = ""
)

# Install required modules
if (-not (Get-Module -ListAvailable -Name Az.Websites)) {
    Install-Module -Name Az.Websites -Force -Scope CurrentUser
}

# Initialize logging
$logPath = "C:\temp\app-service-chaos-validation.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $Message"
    Write-Host $Message
}

# Test App Service basic connectivity
function Test-AppServiceConnectivity {
    Write-Log "Testing App Service connectivity..."
    
    try {
        $appService = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $AppServiceName
        $siteUrl = "https://$($appService.DefaultHostName)"
        
        if ($ProbeUrl) {
            $testUrl = $ProbeUrl
        } else {
            $testUrl = "$siteUrl/api/health"
        }
        
        $response = Invoke-WebRequest -Uri $testUrl -Method Get -TimeoutSec 30 -UseBasicParsing
        $statusCode = $response.StatusCode
        
        if ($statusCode -eq 200) {
            Write-Log "✓ App Service responding successfully (HTTP $statusCode)"
            return $true
        } else {
            Write-Log "✗ App Service responding with HTTP $statusCode"
            return $false
        }
    }
    catch {
        Write-Log "✗ App Service connectivity failed: $($_.Exception.Message)"
        return $false
    }
}

# Test App Service health endpoints
function Test-AppServiceHealth {
    Write-Log "Testing App Service health endpoints..."
    
    try {
        $appService = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $AppServiceName
        $siteUrl = "https://$($appService.DefaultHostName)"
        
        $healthEndpoints = @(
            "/health",
            "/api/health",
            "/healthz",
            "/ready",
            "/api/ready"
        )
        
        $healthyEndpoints = 0
        
        foreach ($endpoint in $healthEndpoints) {
            try {
                $response = Invoke-WebRequest -Uri "$siteUrl$endpoint" -Method Get -TimeoutSec 10 -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    $healthyEndpoints++
                    Write-Log "✓ Health endpoint $endpoint responding"
                }
            }
            catch {
                Write-Log "✗ Health endpoint $endpoint not responding"
            }
        }
        
        if ($healthyEndpoints -gt 0) {
            Write-Log "✓ $healthyEndpoints health endpoints responding"
            return $true
        } else {
            Write-Log "✗ No health endpoints responding"
            return $false
        }
    }
    catch {
        Write-Log "✗ Health check failed: $($_.Exception.Message)"
        return $false
    }
}

# Test App Service application functionality
function Test-AppServiceFunctionality {
    Write-Log "Testing App Service application functionality..."
    
    try {
        $appService = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $AppServiceName
        $siteUrl = "https://$($appService.DefaultHostName)"
        
        # Test basic GET request
        try {
            $response = Invoke-WebRequest -Uri "$siteUrl/" -Method Get -TimeoutSec 15 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Log "✓ GET request successful"
            } else {
                Write-Log "✗ GET request failed with HTTP $($response.StatusCode)"
                return $false
            }
        }
        catch {
            Write-Log "✗ GET request failed: $($_.Exception.Message)"
            return $false
        }
        
        # Test POST request if API endpoint exists
        try {
            $postData = @{ test = "chaos-validation"; timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ") } | ConvertTo-Json
            $response = Invoke-RestMethod -Uri "$siteUrl/api/test" -Method Post -Body $postData -ContentType "application/json" -TimeoutSec 15
            Write-Log "✓ POST request successful"
        }
        catch {
            Write-Log "⚠ POST request failed (endpoint may not exist): $($_.Exception.Message)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Functionality test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test App Service performance
function Test-AppServicePerformance {
    Write-Log "Testing App Service performance..."
    
    try {
        $appService = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $AppServiceName
        $siteUrl = "https://$($appService.DefaultHostName)"
        
        $responseTimes = @()
        
        # Make multiple requests and measure response time
        for ($i = 1; $i -le 10; $i++) {
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $response = Invoke-WebRequest -Uri "$siteUrl/" -Method Get -TimeoutSec 15 -UseBasicParsing
                $stopwatch.Stop()
                $responseTimes += $stopwatch.ElapsedMilliseconds
                
                if ($response.StatusCode -ne 200) {
                    Write-Log "✗ Request $i failed with HTTP $($response.StatusCode)"
                    return $false
                }
            }
            catch {
                Write-Log "✗ Request $i failed: $($_.Exception.Message)"
                return $false
            }
        }
        
        $avgResponseTime = ($responseTimes | Measure-Object -Average).Average
        $maxResponseTime = ($responseTimes | Measure-Object -Maximum).Maximum
        
        Write-Log "Average response time: $([math]::Round($avgResponseTime, 2))ms"
        Write-Log "Maximum response time: $maxResponseTime ms"
        
        # Performance thresholds (adjust based on your requirements)
        if ($avgResponseTime -lt 2000 -and $maxResponseTime -lt 5000) {
            Write-Log "✓ Performance within acceptable limits"
            return $true
        } else {
            Write-Log "✗ Performance degraded beyond acceptable limits"
            return $false
        }
    }
    catch {
        Write-Log "✗ Performance test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test App Service scaling
function Test-AppServiceScaling {
    Write-Log "Testing App Service scaling..."
    
    try {
        $appServicePlan = Get-AzWebAppPlan -ResourceGroupName $ResourceGroup -Name $AppServiceName
        
        # Check current instance count
        $currentInstances = $appServicePlan.Capacity
        Write-Log "Current instance count: $currentInstances"
        
        # Get scaling rules if auto-scaling is configured
        try {
            $autoScaleSettings = Get-AzAutoscaleSetting -ResourceGroupName $ResourceGroup | Where-Object { $_.TargetResourceUri -like "*$AppServiceName*" }
            
            if ($autoScaleSettings) {
                Write-Log "✓ Auto-scaling configured"
                foreach ($setting in $autoScaleSettings) {
                    Write-Log "  - Profile: $($setting.Profiles[0].Name)"
                    Write-Log "  - Min instances: $($setting.Profiles[0].Capacity.Minimum)"
                    Write-Log "  - Max instances: $($setting.Profiles[0].Capacity.Maximum)"
                    Write-Log "  - Default instances: $($setting.Profiles[0].Capacity.Default)"
                }
                return $true
            } else {
                Write-Log "⚠ No auto-scaling configured"
                return $true
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve auto-scaling settings"
            return $true
        }
    }
    catch {
        Write-Log "✗ Scaling test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test App Service deployment slots
function Test-AppServiceSlots {
    Write-Log "Testing App Service deployment slots..."
    
    try {
        $slots = Get-AzWebAppSlot -ResourceGroupName $ResourceGroup -Name $AppServiceName
        
        if ($slots.Count -gt 1) {
            Write-Log "✓ Multiple deployment slots found"
            
            foreach ($slot in $slots) {
                $slotName = $slot.Name.Split("/")[-1]
                $slotUrl = "https://$($slot.DefaultHostName)"
                
                try {
                    $response = Invoke-WebRequest -Uri "$slotUrl/" -Method Get -TimeoutSec 15 -UseBasicParsing
                    Write-Log "✓ Slot '$slotName' responding (HTTP $($response.StatusCode))"
                }
                catch {
                    Write-Log "✗ Slot '$slotName' not responding: $($_.Exception.Message)"
                }
            }
            
            return $true
        } else {
            Write-Log "⚠ Only production slot found"
            return $true
        }
    }
    catch {
        Write-Log "✗ Slot test failed: $($_.Exception.Message)"
        return $false
    }
}

# Get App Service metrics
function Get-AppServiceMetrics {
    Write-Log "Collecting App Service metrics..."
    
    try {
        $resourceId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$AppServiceName"
        
        $metrics = @()
        
        # HTTP 5xx errors
        $http5xx = Get-AzMetric -ResourceId $resourceId -MetricNames "Http5xx" -TimeGrain 00:01:00 -AggregationType Maximum
        $metrics += @{
            Name = "Http5xx"
            Value = ($http5xx | Select-Object -Last 1).Data.Maximum
            Unit = "Count"
        }
        
        # CPU percentage
        $cpu = Get-AzMetric -ResourceId $resourceId -MetricNames "CpuPercentage" -TimeGrain 00:01:00 -AggregationType Average
        $metrics += @{
            Name = "CpuPercentage"
            Value = ($cpu | Select-Object -Last 1).Data.Average
            Unit = "Percent"
        }
        
        # Memory percentage
        $memory = Get-AzMetric -ResourceId $resourceId -MetricNames "MemoryPercentage" -TimeGrain 00:01:00 -AggregationType Average
        $metrics += @{
            Name = "MemoryPercentage"
            Value = ($memory | Select-Object -Last 1).Data.Average
            Unit = "Percent"
        }
        
        # Response time
        $responseTime = Get-AzMetric -ResourceId $resourceId -MetricNames "HttpResponseTime" -TimeGrain 00:01:00 -AggregationType Average
        $metrics += @{
            Name = "HttpResponseTime"
            Value = ($responseTime | Select-Object -Last 1).Data.Average
            Unit = "Seconds"
        }
        
        # Request count
        $requests = Get-AzMetric -ResourceId $resourceId -MetricNames "Requests" -TimeGrain 00:01:00 -AggregationType Total
        $metrics += @{
            Name = "Requests"
            Value = ($requests | Select-Object -Last 1).Data.Total
            Unit = "Count"
        }
        
        return $metrics
    }
    catch {
        Write-Log "✗ Failed to collect metrics: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
Write-Log "Starting App Service chaos validation..."
Write-Log "Resource Group: $ResourceGroup"
Write-Log "App Service: $AppServiceName"
Write-Log "Slot: $SlotName"

$testResults = @()

# Run all tests
$testResults += @{ Test = "Connectivity"; Result = (Test-AppServiceConnectivity) }
$testResults += @{ Test = "HealthEndpoints"; Result = (Test-AppServiceHealth) }
$testResults += @{ Test = "Functionality"; Result = (Test-AppServiceFunctionality) }
$testResults += @{ Test = "Performance"; Result = (Test-AppServicePerformance) }
$testResults += @{ Test = "Scaling"; Result = (Test-AppServiceScaling) }
$testResults += @{ Test = "DeploymentSlots"; Result = (Test-AppServiceSlots) }

# Get metrics
$metrics = Get-AppServiceMetrics

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
    Write-Log "All tests passed - App Service healthy"
    exit 0
} else {
    Write-Log "Some tests failed - App Service issues detected"
    exit 1
}
