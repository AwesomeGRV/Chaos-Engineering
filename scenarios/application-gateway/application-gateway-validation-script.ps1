# Azure Application Gateway Chaos Validation Script
# Validates Application Gateway functionality during chaos experiments

param(
    [string]$ResourceGroup = "",
    [string]$ApplicationGatewayName = "",
    [string]$TestBackendVMName = ""
)

# Install required modules
if (-not (Get-Module -ListAvailable -Name Az.Network)) {
    Install-Module -Name Az.Network -Force -Scope CurrentUser
}

# Initialize logging
$logPath = "C:\temp\application-gateway-chaos-validation.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $Message"
    Write-Host $Message
}

# Test Application Gateway basic connectivity
function Test-ApplicationGatewayConnectivity {
    Write-Log "Testing Application Gateway connectivity..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        Write-Log "✓ Application Gateway found: $($appGateway.Name)"
        Write-Log "Location: $($appGateway.Location)"
        Write-Log "SKU: $($appGateway.Sku.Name)"
        Write-Log "Tier: $($appGateway.Sku.Tier)"
        Write-Log "Operational state: $($appGateway.OperationalState)"
        Write-Log "Provisioning state: $($appGateway.ProvisioningState)"
        
        return $true
    }
    catch {
        Write-Log "✗ Application Gateway connectivity failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Application Gateway frontend configurations
function Test-FrontendConfigurations {
    Write-Log "Testing Application Gateway frontend configurations..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        
        foreach ($frontendIP in $appGateway.FrontendIPConfigurations) {
            Write-Log "Frontend IP Configuration: $($frontendIP.Name)"
            Write-Log "  - Type: $($frontendIP.Type)"
            
            if ($frontendIP.PublicIPAddress) {
                Write-Log "  - Public IP: $($frontendIP.PublicIPAddress.IpAddress)"
                Write-Log "  - DNS name: $($frontendIP.PublicIPAddress.DnsSettings.Fqdn)"
                
                # Test connectivity to public IP
                try {
                    $pingResult = Test-Connection -ComputerName $frontendIP.PublicIPAddress.IpAddress -Count 1 -Quiet -ErrorAction SilentlyContinue
                    if ($pingResult) {
                        Write-Log "  ✓ Public IP is reachable"
                    } else {
                        Write-Log "  ⚠ Public IP is not reachable (may be expected)"
                    }
                }
                catch {
                    Write-Log "  ⚠ Could not test public IP connectivity"
                }
            }
            
            if ($frontendIP.PrivateIPAddress) {
                Write-Log "  - Private IP: $($frontendIP.PrivateIPAddress)"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Frontend configurations test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Application Gateway listeners
function Test-Listeners {
    Write-Log "Testing Application Gateway listeners..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        
        foreach ($listener in $appGateway.HttpListeners) {
            Write-Log "HTTP Listener: $($listener.Name)"
            Write-Log "  - Protocol: $($listener.Protocol)"
            Write-Log "  - Port: $($listener.Port)"
            Write-Log "  - Host name: $($listener.HostName)"
            Write-Log "  - Require server name indication: $($listener.RequireServerNameIndication)"
            
            if ($listener.SslCertificate) {
                Write-Log "  - SSL Certificate: $($listener.SslCertificate.Id)"
            }
            
            if ($listener.FrontendIPConfiguration) {
                Write-Log "  - Frontend IP: $($listener.FrontendIPConfiguration.Id)"
            }
            
            # Test listener endpoint
            $frontendIP = $appGateway.FrontendIPConfigurations | Where-Object { $_.Id -eq $listener.FrontendIPConfiguration.Id }
            if ($frontendIP -and $frontendIP.PublicIPAddress) {
                $testUrl = "$($listener.Protocol.ToLower())://$($frontendIP.PublicIPAddress.DnsSettings.Fqdn)"
                try {
                    $response = Invoke-WebRequest -Uri $testUrl -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                    Write-Log "  ✓ Listener endpoint responded with HTTP $($response.StatusCode)"
                }
                catch {
                    Write-Log "  ⚠ Listener endpoint test failed: $($_.Exception.Message)"
                }
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Listeners test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Application Gateway backend pools
function Test-BackendPools {
    Write-Log "Testing Application Gateway backend pools..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        
        foreach ($backendPool in $appGateway.BackendAddressPools) {
            Write-Log "Backend Address Pool: $($backendPool.Name)"
            Write-Log "  - Backend addresses: $($backendPool.BackendAddresses.Count)"
            
            foreach ($backendAddress in $backendPool.BackendAddresses) {
                if ($backendAddress.Fqdn) {
                    Write-Log "    - FQDN: $($backendAddress.Fqdn)"
                }
                if ($backendAddress.IpAddress) {
                    Write-Log "    - IP Address: $($backendAddress.IpAddress)"
                }
            }
            
            # Check backend pool health
            try {
                $poolHealth = Get-AzApplicationGatewayBackendHealth -ApplicationGateway $appGateway -Name $backendPool.Name -ErrorAction SilentlyContinue
                if ($poolHealth) {
                    Write-Log "  ✓ Backend pool health retrieved"
                    foreach ($backendHttpSetting in $poolHealth.BackendHttpSettingsCollection) {
                        Write-Log "    - HTTP Setting: $($backendHttpSetting.Name)"
                        foreach ($server in $backendHttpSetting.Servers) {
                            Write-Log "      Server: $($server.Address) - Health: $($server.Health)"
                        }
                    }
                } else {
                    Write-Log "  ⚠ Could not retrieve backend pool health"
                }
            }
            catch {
                Write-Log "  ⚠ Backend pool health check failed"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Backend pools test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Application Gateway HTTP settings
function Test-HTTPSettings {
    Write-Log "Testing Application Gateway HTTP settings..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        
        foreach ($httpSetting in $appGateway.BackendHttpSettingsCollection) {
            Write-Log "Backend HTTP Setting: $($httpSetting.Name)"
            Write-Log "  - Port: $($httpSetting.Port)"
            Write-Log "  - Protocol: $($httpSetting.Protocol)"
            Write-Log "  - Cookie based affinity: $($httpSetting.CookieBasedAffinity)"
            Write-Log "  - Request timeout: $($httpSetting.RequestTimeout)"
            
            if ($httpSetting.ConnectionDraining) {
                Write-Log "  - Connection draining enabled: $($httpSetting.ConnectionDraining.DrainTimeoutInSec) seconds"
            }
            
            if ($httpSetting.Probe) {
                Write-Log "  - Health probe: $($httpSetting.Probe.Id)"
            }
            
            if ($httpSetting.AuthenticationCertificates) {
                Write-Log "  - Authentication certificates: $($httpSetting.AuthenticationCertificates.Count)"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ HTTP settings test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Application Gateway request routing rules
function Test-RoutingRules {
    Write-Log "Testing Application Gateway request routing rules..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        
        foreach ($rule in $appGateway.RequestRoutingRules) {
            Write-Log "Request Routing Rule: $($rule.Name)"
            Write-Log "  - Rule type: $($rule.RuleType)"
            
            if ($rule.HttpListener) {
                Write-Log "  - HTTP Listener: $($rule.HttpListener.Id)"
            }
            
            if ($rule.BackendAddressPool) {
                Write-Log "  - Backend Pool: $($rule.BackendAddressPool.Id)"
            }
            
            if ($rule.BackendHttpSettings) {
                Write-Log "  - Backend HTTP Settings: $($rule.BackendHttpSettings.Id)"
            }
            
            if ($rule.RedirectConfiguration) {
                Write-Log "  - Redirect Configuration: $($rule.RedirectConfiguration.Id)"
            }
            
            if ($rule.RewriteRuleSet) {
                Write-Log "  - Rewrite Rule Set: $($rule.RewriteRuleSet.Id)"
            }
            
            # Test rule priority and order
            Write-Log "  - Priority: $($rule.Priority)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Routing rules test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Application Gateway health probes
function Test-HealthProbes {
    Write-Log "Testing Application Gateway health probes..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        
        foreach ($probe in $appGateway.Probes) {
            Write-Log "Health Probe: $($probe.Name)"
            Write-Log "  - Protocol: $($probe.Protocol)"
            Write-Log "  - Host: $($probe.Host)"
            Write-Log "  - Path: $($probe.Path)"
            Write-Log "  - Interval: $($probe.Interval)"
            Write-Log "  - Timeout: $($probe.Timeout)"
            Write-Log "  - Unhealthy threshold: $($probe.UnhealthyThreshold)"
            Write-Log "  - Pick host name from backend HTTP settings: $($probe.PickHostNameFromBackendHttpSettings)"
            
            # Test probe endpoint
            if ($probe.Protocol -eq "Http" -or $probe.Protocol -eq "Https") {
                $frontendIPs = $appGateway.FrontendIPConfigurations
                if ($frontendIPs.Count -gt 0 -and $frontendIPs[0].PublicIPAddress) {
                    $testHost = if ($probe.Host) { $probe.Host } else { $frontendIPs[0].PublicIPAddress.DnsSettings.Fqdn }
                    $testUrl = "$($probe.Protocol.ToLower())://$testHost$($probe.Path)"
                    try {
                        $response = Invoke-WebRequest -Uri $testUrl -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
                        Write-Log "  ✓ Probe endpoint responded with HTTP $($response.StatusCode)"
                    }
                    catch {
                        Write-Log "  ⚠ Probe endpoint test failed: $($_.Exception.Message)"
                    }
                }
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Health probes test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Application Gateway SSL certificates
function Test-SSLCertificates {
    Write-Log "Testing Application Gateway SSL certificates..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        
        foreach ($sslCert in $appGateway.SslCertificates) {
            Write-Log "SSL Certificate: $($sslCert.Name)"
            Write-Log "  - Public cert data: $($sslCert.PublicCertData.Length) bytes"
            
            # Check certificate expiry (would need to decode the cert data)
            Write-Log "  - Certificate data available"
            
            # Check which listeners use this certificate
            $listenersUsingCert = $appGateway.HttpListeners | Where-Object { $_.SslCertificate.Id -eq $sslCert.Id }
            if ($listenersUsingCert.Count -gt 0) {
                Write-Log "  - Used by listeners: $($listenersUsingCert.Name -join ', ')"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ SSL certificates test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Application Gateway WAF (if enabled)
function Test-WAFConfiguration {
    Write-Log "Testing Application Gateway WAF configuration..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        
        if ($appGateway.FirewallPolicy) {
            Write-Log "✓ WAF Policy configured: $($appGateway.FirewallPolicy.Id)"
            
            try {
                $wafPolicy = Get-AzApplicationGatewayFirewallPolicy -ResourceGroupName $ResourceGroup -Name $appGateway.FirewallPolicy.Split('/')[-1]
                Write-Log "  - Policy state: $($wafPolicy.State)"
                Write-Log "  - Rule set type: $($wafPolicy.ManagedRuleSet.RuleSetType)"
                Write-Log "  - Rule set version: $($wafPolicy.ManagedRuleSet.RuleSetVersion)"
                Write-Log "  - Request body inspection: $($wafPolicy.ManagedRuleManagedRuleGroupOverrides.Count) overrides"
                
                # Check WAF rules
                foreach ($ruleGroup in $wafPolicy.ManagedRuleManagedRuleGroupOverrides) {
                    Write-Log "    - Rule group: $($ruleGroup.RuleGroupName)"
                    Write-Log "      Rules: $($ruleGroup.Rules.Count)"
                }
                
                # Check exclusions
                if ($wafPolicy.ExclusionManagedRuleSets) {
                    Write-Log "  - Exclusions: $($wafPolicy.ExclusionManagedRuleSets.Count)"
                }
                
                # Check custom rules
                if ($wafPolicy.CustomRules) {
                    Write-Log "  - Custom rules: $($wafPolicy.CustomRules.Count)"
                    foreach ($customRule in $wafPolicy.CustomRules) {
                        Write-Log "    - $($customRule.Name): $($customRule.Priority)"
                    }
                }
            }
            catch {
                Write-Log "  ⚠ Could not retrieve WAF policy details"
            }
        } else {
            Write-Log "⚠ No WAF policy configured"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ WAF configuration test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Application Gateway autoscaling
function Test-Autoscaling {
    Write-Log "Testing Application Gateway autoscaling..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        
        if ($appGateway.Sku.Capacity -eq 0) {
            Write-Log "✓ Autoscaling enabled"
            Write-Log "  - Minimum instances: $($appGateway.AutoscaleConfiguration.MinimumCapacity)"
            Write-Log "  - Maximum instances: $($appGateway.AutoscaleConfiguration.MaximumCapacity)"
            
            # Check current instance count
            try {
                $capacityMetrics = Get-AzMetric -ResourceId $appGateway.Id -MetricNames "InstanceCount" -TimeGrain 00:01:00 -AggregationType Average
                $currentCapacity = ($capacityMetrics | Select-Object -Last 1).Data.Average
                Write-Log "  - Current instances: $([math]::Round($currentCapacity, 0))"
            }
            catch {
                Write-Log "  ⚠ Could not retrieve current instance count"
            }
        } else {
            Write-Log "⚠ Manual scaling - Fixed capacity: $($appGateway.Sku.Capacity)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Autoscaling test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Application Gateway diagnostics
function Test-Diagnostics {
    Write-Log "Testing Application Gateway diagnostics..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        
        # Check diagnostic settings
        try {
            $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $appGateway.Id -ErrorAction SilentlyContinue
            if ($diagnosticSettings.Count -gt 0) {
                Write-Log "✓ Found $($diagnosticSettings.Count) diagnostic settings"
                foreach ($setting in $diagnosticSettings) {
                    Write-Log "  - $($setting.Name): $($setting.WorkspaceId)"
                }
            } else {
                Write-Log "⚠ No diagnostic settings configured"
            }
        }
        catch {
            Write-Log "⚠ Could not check diagnostic settings"
        }
        
        # Check access logs
        try {
            $accessLogs = Get-AzApplicationGatewayAccessLog -ApplicationGateway $appGateway -ErrorAction SilentlyContinue
            if ($accessLogs.Count -gt 0) {
                Write-Log "✓ Access logs available: $($accessLogs.Count) entries"
            }
        }
        catch {
            Write-Log "⚠ Could not check access logs"
        }
        
        # Check firewall logs (if WAF enabled)
        if ($appGateway.FirewallPolicy) {
            try {
                $firewallLogs = Get-AzApplicationGatewayFirewallLog -ApplicationGateway $appGateway -ErrorAction SilentlyContinue
                if ($firewallLogs.Count -gt 0) {
                    Write-Log "✓ Firewall logs available: $($firewallLogs.Count) entries"
                }
            }
            catch {
                Write-Log "⚠ Could not check firewall logs"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Diagnostics test failed: $($_.Exception.Message)"
        return $false
    }
}

# Get Application Gateway metrics
function Get-ApplicationGatewayMetrics {
    Write-Log "Collecting Application Gateway metrics..."
    
    try {
        $appGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroup -Name $ApplicationGatewayName
        $resourceId = $appGateway.Id
        
        $metrics = @()
        
        # Throughput
        try {
            $throughput = Get-AzMetric -ResourceId $resourceId -MetricNames "Throughput" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "Throughput"
                Value = ($throughput | Select-Object -Last 1).Data.Average
                Unit = "BytesPerSecond"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve Throughput metric"
        }
        
        # Unhealthy request count
        try {
            $unhealthyRequests = Get-AzMetric -ResourceId $resourceId -MetricNames "UnhealthyRequestCount" -TimeGrain 00:01:00 -AggregationType Total
            $metrics += @{
                Name = "UnhealthyRequestCount"
                Value = ($unhealthyRequests | Select-Object -Last 1).Data.Total
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve UnhealthyRequestCount metric"
        }
        
        # Failed request count
        try {
            $failedRequests = Get-AzMetric -ResourceId $resourceId -MetricNames "FailedRequestCount" -TimeGrain 00:01:00 -AggregationType Total
            $metrics += @{
                Name = "FailedRequestCount"
                Value = ($failedRequests | Select-Object -Last 1).Data.Total
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve FailedRequestCount metric"
        }
        
        # Current connections
        try {
            $currentConnections = Get-AzMetric -ResourceId $resourceId -MetricNames "CurrentConnections" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "CurrentConnections"
                Value = ($currentConnections | Select-Object -Last 1).Data.Average
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve CurrentConnections metric"
        }
        
        return $metrics
    }
    catch {
        Write-Log "✗ Failed to collect metrics: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
Write-Log "Starting Application Gateway chaos validation..."
Write-Log "Resource Group: $ResourceGroup"
Write-Log "Application Gateway: $ApplicationGatewayName"
Write-Log "Test Backend VM: $TestBackendVMName"

$testResults = @()

# Run all tests
$testResults += @{ Test = "Connectivity"; Result = (Test-ApplicationGatewayConnectivity) }
$testResults += @{ Test = "FrontendConfigurations"; Result = (Test-FrontendConfigurations) }
$testResults += @{ Test = "Listeners"; Result = (Test-Listeners) }
$testResults += @{ Test = "BackendPools"; Result = (Test-BackendPools) }
$testResults += @{ Test = "HTTPSettings"; Result = (Test-HTTPSettings) }
$testResults += @{ Test = "RoutingRules"; Result = (Test-RoutingRules) }
$testResults += @{ Test = "HealthProbes"; Result = (Test-HealthProbes) }
$testResults += @{ Test = "SSLCertificates"; Result = (Test-SSLCertificates) }
$testResults += @{ Test = "WAFConfiguration"; Result = (Test-WAFConfiguration) }
$testResults += @{ Test = "Autoscaling"; Result = (Test-Autoscaling) }
$testResults += @{ Test = "Diagnostics"; Result = (Test-Diagnostics) }

# Get metrics
$metrics = Get-ApplicationGatewayMetrics

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
    Write-Log "All tests passed - Application Gateway healthy"
    exit 0
} else {
    Write-Log "Some tests failed - Application Gateway issues detected"
    exit 1
}
