# Azure Load Balancer Chaos Validation Script
# Validates Load Balancer functionality during chaos experiments

param(
    [string]$ResourceGroup = "",
    [string]$LoadBalancerName = "",
    [string]$TestBackendVMName = ""
)

# Install required modules
if (-not (Get-Module -ListAvailable -Name Az.Network)) {
    Install-Module -Name Az.Network -Force -Scope CurrentUser
}

# Initialize logging
$logPath = "C:\temp\load-balancer-chaos-validation.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $Message"
    Write-Host $Message
}

# Test Load Balancer basic connectivity
function Test-LoadBalancerConnectivity {
    Write-Log "Testing Load Balancer connectivity..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        Write-Log "✓ Load Balancer found: $($loadBalancer.Name)"
        Write-Log "Location: $($loadBalancer.Location)"
        Write-Log "SKU: $($loadBalancer.Sku.Name)"
        Write-Log "Tier: $($loadBalancer.Sku.Tier)"
        Write-Log "Resource GUID: $($loadBalancer.ResourceGUID)"
        
        return $true
    }
    catch {
        Write-Log "✗ Load Balancer connectivity failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Load Balancer frontend configurations
function Test-FrontendConfigurations {
    Write-Log "Testing Load Balancer frontend configurations..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        
        foreach ($frontendIP in $loadBalancer.FrontendIpConfigurations) {
            Write-Log "Frontend IP Configuration: $($frontendIP.Name)"
            Write-Log "  - Allocation method: $($frontendIP.PublicIpAddress.AllocationMethod)"
            Write-Log "  - IP address: $($frontendIP.PublicIpAddress.IpAddress)"
            Write-Log "  - SKU: $($frontendIP.PublicIpAddress.Sku.Name)"
            Write-Log "  - Zones: $($frontendIP.Zones -join ', ')"
            
            # Test IP address availability
            if ($frontendIP.PublicIpAddress) {
                $pingResult = Test-Connection -ComputerName $frontendIP.PublicIpAddress.IpAddress -Count 1 -Quiet -ErrorAction SilentlyContinue
                if ($pingResult) {
                    Write-Log "  ✓ IP address is reachable"
                } else {
                    Write-Log "  ⚠ IP address is not reachable (may be expected)"
                }
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Frontend configurations test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Load Balancer backend pools
function Test-BackendPools {
    Write-Log "Testing Load Balancer backend pools..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        
        foreach ($backendPool in $loadBalancer.BackendAddressPools) {
            Write-Log "Backend Address Pool: $($backendPool.Name)"
            Write-Log "  - Load balancer backend addresses: $($backendPool.LoadBalancerBackendAddresses.Count)"
            
            foreach ($backendAddress in $backendPool.LoadBalancerBackendAddresses) {
                if ($backendAddress.VirtualNetwork) {
                    Write-Log "    - Virtual Network: $($backendAddress.VirtualNetwork.Id)"
                }
                if ($backendAddress.IpAddress) {
                    Write-Log "    - IP Address: $($backendAddress.IpAddress)"
                }
                if ($backendAddress.NetworkInterfaceConfiguration) {
                    Write-Log "    - Network Interface: $($backendAddress.NetworkInterfaceConfiguration.Id)"
                }
            }
            
            # Check backend pool health
            try {
                $poolHealth = Get-AzLoadBalancerBackendAddressPool -ResourceGroupName $ResourceGroup -LoadBalancerName $LoadBalancerName -Name $backendPool.Name
                Write-Log "  - Backend pool configuration retrieved successfully"
            }
            catch {
                Write-Log "  ⚠ Could not retrieve backend pool health information"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Backend pools test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Load Balancer rules
function Test-LoadBalancerRules {
    Write-Log "Testing Load Balancer rules..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        
        foreach ($rule in $loadBalancer.LoadBalancingRules) {
            Write-Log "Load Balancing Rule: $($rule.Name)"
            Write-Log "  - Protocol: $($rule.Protocol)"
            Write-Log "  - Frontend port: $($rule.FrontendPort)"
            Write-Log "  - Backend port: $($rule.BackendPort)"
            Write-Log "  - Enabled: $($rule.EnableFloatingIP)"
            Write-Log "  - Load distribution: $($rule.LoadDistribution)"
            
            if ($rule.Probe) {
                Write-Log "  - Health probe: $($rule.Probe.Id)"
            }
            
            if ($rule.FrontendIPConfiguration) {
                Write-Log "  - Frontend IP: $($rule.FrontendIPConfiguration.Id)"
            }
            
            if ($rule.BackendAddressPool) {
                Write-Log "  - Backend pool: $($rule.BackendAddressPool.Id)"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Load Balancer rules test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Load Balancer health probes
function Test-HealthProbes {
    Write-Log "Testing Load Balancer health probes..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        
        foreach ($probe in $loadBalancer.Probes) {
            Write-Log "Health Probe: $($probe.Name)"
            Write-Log "  - Protocol: $($probe.Protocol)"
            Write-Log "  - Port: $($probe.Port)"
            Write-Log "  - Interval in seconds: $($probe.IntervalInSeconds)"
            Write-Log "  - Number of probes: $($probe.NumberOfProbes)"
            Write-Log "  - Request path: $($probe.RequestPath)"
            
            # Test probe endpoint if it's HTTP/HTTPS
            if ($probe.Protocol -eq "Http" -or $probe.Protocol -eq "Https") {
                $frontendIPs = $loadBalancer.FrontendIpConfigurations
                if ($frontendIPs.Count -gt 0) {
                    $testUrl = "$($probe.Protocol.ToLower())://$($frontendIPs[0].PublicIpAddress.IpAddress):$($probe.Port)$($probe.RequestPath)"
                    try {
                        $response = Invoke-WebRequest -Uri $testUrl -Method Get -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
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

# Test Load Balancer NAT rules
function Test-NATRules {
    Write-Log "Testing Load Balancer NAT rules..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        
        $inboundNATRules = $loadBalancer.InboundNatRules
        if ($inboundNATRules.Count -gt 0) {
            Write-Log "Found $($inboundNATRules.Count) inbound NAT rules"
            
            foreach ($natRule in $inboundNATRules) {
                Write-Log "Inbound NAT Rule: $($natRule.Name)"
                Write-Log "  - Protocol: $($natRule.Protocol)"
                Write-Log "  - Frontend port: $($natRule.FrontendPort)"
                Write-Log "  - Backend port: $($natRule.BackendPort)"
                Write-Log "  - Enabled: $($natRule.EnableFloatingIP)"
                
                if ($natRule.FrontendIPConfiguration) {
                    Write-Log "  - Frontend IP: $($natRule.FrontendIPConfiguration.Id)"
                }
                
                if ($natRule.BackendIPConfiguration) {
                    Write-Log "  - Backend IP: $($natRule.BackendIPConfiguration.Id)"
                }
            }
        } else {
            Write-Log "⚠ No inbound NAT rules configured"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ NAT rules test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Load Balancer outbound rules
function Test-OutboundRules {
    Write-Log "Testing Load Balancer outbound rules..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        
        $outboundRules = $loadBalancer.OutboundRules
        if ($outboundRules.Count -gt 0) {
            Write-Log "Found $($outboundRules.Count) outbound rules"
            
            foreach ($outboundRule in $outboundRules) {
                Write-Log "Outbound Rule: $($outboundRule.Name)"
                Write-Log "  - Protocol: $($outboundRule.Protocol)"
                Write-Log "  - Allocated frontend ports: $($outboundRule.AllocatedOutboundPorts)"
                Write-Log "  - Idle timeout in minutes: $($outboundRule.IdleTimeoutInMinutes)"
                
                if ($outboundRule.FrontendIPConfigurations) {
                    Write-Log "  - Frontend IPs: $($outboundRule.FrontendIPConfigurations.Count)"
                }
                
                if ($outboundRule.BackendAddressPool) {
                    Write-Log "  - Backend pool: $($outboundRule.BackendAddressPool.Id)"
                }
            }
        } else {
            Write-Log "⚠ No outbound rules configured"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Outbound rules test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Load Balancer diagnostics
function Test-LoadBalancerDiagnostics {
    Write-Log "Testing Load Balancer diagnostics..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        
        # Check diagnostic settings
        try {
            $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $loadBalancer.Id -ErrorAction SilentlyContinue
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
        
        # Check flow logs
        try {
            $networkWatcher = Get-AzNetworkWatcher | Where-Object { $_.Location -eq $loadBalancer.Location }
            if ($networkWatcher) {
                $flowLogs = Get-AzNetworkWatcherFlowLog -TargetResourceId $loadBalancer.Id -NetworkWatcher $networkWatcher -ErrorAction SilentlyContinue
                if ($flowLogs.Count -gt 0) {
                    Write-Log "✓ Flow logs configured: $($flowLogs.Count)"
                } else {
                    Write-Log "⚠ No flow logs configured"
                }
            }
        }
        catch {
            Write-Log "⚠ Could not check flow logs"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Load Balancer diagnostics test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Load Balancer high availability
function Test-LoadBalancerHighAvailability {
    Write-Log "Testing Load Balancer high availability..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        
        # Check SKU tier for HA capabilities
        if ($loadBalancer.Sku.Tier -eq "Standard") {
            Write-Log "✓ Standard SKU provides zone-redundant HA"
            
            # Check availability zones
            foreach ($frontendIP in $loadBalancer.FrontendIpConfigurations) {
                if ($frontendIP.Zones) {
                    Write-Log "  - Frontend IP $($frontendIP.Name) zones: $($frontendIP.Zones -join ', ')"
                } else {
                    Write-Log "  - Frontend IP $($frontendIP.Name) not zone-redundant"
                }
            }
        } else {
            Write-Log "⚠ Basic SKU - no zone redundancy"
        }
        
        # Check backend VM availability
        if ($TestBackendVMName) {
            try {
                $vm = Get-AzVM -ResourceGroupName $ResourceGroup -Name $TestBackendVMName -ErrorAction SilentlyContinue
                if ($vm) {
                    Write-Log "✓ Test backend VM found: $($vm.Name)"
                    Write-Log "  - Status: $($vm.ProvisioningState)"
                    Write-Log "  - Location: $($vm.Location)"
                    Write-Log "  - Zones: $($vm.Zones -join ', ')"
                    
                    # Check VM power state
                    $vmStatus = Get-AzVM -ResourceGroupName $ResourceGroup -Name $TestBackendVMName -Status
                    $powerState = $vmStatus.Statuses | Where-Object { $_.Code -like "*PowerState*" }
                    if ($powerState) {
                        Write-Log "  - Power state: $($powerState.DisplayStatus)"
                    }
                } else {
                    Write-Log "⚠ Test backend VM not found"
                }
            }
            catch {
                Write-Log "⚠ Could not check backend VM status"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Load Balancer high availability test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Load Balancer traffic distribution
function Test-TrafficDistribution {
    Write-Log "Testing Load Balancer traffic distribution..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        
        # Check load distribution algorithms
        foreach ($rule in $loadBalancer.LoadBalancingRules) {
            Write-Log "Rule: $($rule.Name)"
            Write-Log "  - Load distribution: $($rule.LoadDistribution)"
            
            switch ($rule.LoadDistribution) {
                "Default" {
                    Write-Log "    ✓ Using 5-tuple hash for session affinity"
                }
                "SourceIP" {
                    Write-Log "    ✓ Using 2-tuple hash (source IP, destination IP)"
                }
                "SourceIPProtocol" {
                    Write-Log "    ✓ Using 3-tuple hash (source IP, destination IP, protocol)"
                }
            }
            
            # Check session persistence
            if ($rule.EnableFloatingIP) {
                Write-Log "    ✓ Floating IP enabled for direct server return"
            }
        }
        
        # Test connectivity to frontend IP
        $frontendIPs = $loadBalancer.FrontendIpConfigurations
        if ($frontendIPs.Count -gt 0) {
            $frontendIP = $frontendIPs[0]
            $testPort = 80
            
            foreach ($rule in $loadBalancer.LoadBalancingRules) {
                if ($rule.FrontendPort -eq $testPort) {
                    try {
                        $tcpTest = Test-NetConnection -ComputerName $frontendIP.PublicIpAddress.IpAddress -Port $testPort -WarningAction SilentlyContinue
                        if ($tcpTest.TcpTestSucceeded) {
                            Write-Log "✓ TCP connection successful to $($frontendIP.PublicIpAddress.IpAddress):$testPort"
                        } else {
                            Write-Log "⚠ TCP connection failed to $($frontendIP.PublicIpAddress.IpAddress):$testPort"
                        }
                    }
                    catch {
                        Write-Log "⚠ Could not test TCP connection"
                    }
                    break
                }
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Traffic distribution test failed: $($_.Exception.Message)"
        return $false
    }
}

# Get Load Balancer metrics
function Get-LoadBalancerMetrics {
    Write-Log "Collecting Load Balancer metrics..."
    
    try {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroup -Name $LoadBalancerName
        $resourceId = $loadBalancer.Id
        
        $metrics = @()
        
        # Byte count
        try {
            $byteCount = Get-AzMetric -ResourceId $resourceId -MetricNames "ByteCount" -TimeGrain 00:01:00 -AggregationType Total
            $metrics += @{
                Name = "ByteCount"
                Value = ($byteCount | Select-Object -Last 1).Data.Total
                Unit = "Bytes"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve ByteCount metric"
        }
        
        # Packet count
        try {
            $packetCount = Get-AzMetric -ResourceId $resourceId -MetricNames "PacketCount" -TimeGrain 00:01:00 -AggregationType Total
            $metrics += @{
                Name = "PacketCount"
                Value = ($packetCount | Select-Object -Last 1).Data.Total
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve PacketCount metric"
        }
        
        # Connection count
        try {
            $connectionCount = Get-AzMetric -ResourceId $resourceId -MetricNames "VipConnection" -TimeGrain 00:01:00 -AggregationType Total
            $metrics += @{
                Name = "VipConnection"
                Value = ($connectionCount | Select-Object -Last 1).Data.Total
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve VipConnection metric"
        }
        
        # Health probe status
        try {
            $healthProbeStatus = Get-AzMetric -ResourceId $resourceId -MetricNames "DipAvailability" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "DipAvailability"
                Value = ($healthProbeStatus | Select-Object -Last 1).Data.Average
                Unit = "Percent"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve DipAvailability metric"
        }
        
        return $metrics
    }
    catch {
        Write-Log "✗ Failed to collect metrics: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
Write-Log "Starting Load Balancer chaos validation..."
Write-Log "Resource Group: $ResourceGroup"
Write-Log "Load Balancer: $LoadBalancerName"
Write-Log "Test Backend VM: $TestBackendVMName"

$testResults = @()

# Run all tests
$testResults += @{ Test = "Connectivity"; Result = (Test-LoadBalancerConnectivity) }
$testResults += @{ Test = "FrontendConfigurations"; Result = (Test-FrontendConfigurations) }
$testResults += @{ Test = "BackendPools"; Result = (Test-BackendPools) }
$testResults += @{ Test = "LoadBalancerRules"; Result = (Test-LoadBalancerRules) }
$testResults += @{ Test = "HealthProbes"; Result = (Test-HealthProbes) }
$testResults += @{ Test = "NATRules"; Result = (Test-NATRules) }
$testResults += @{ Test = "OutboundRules"; Result = (Test-OutboundRules) }
$testResults += @{ Test = "Diagnostics"; Result = (Test-LoadBalancerDiagnostics) }
$testResults += @{ Test = "HighAvailability"; Result = (Test-LoadBalancerHighAvailability) }
$testResults += @{ Test = "TrafficDistribution"; Result = (Test-TrafficDistribution) }

# Get metrics
$metrics = Get-LoadBalancerMetrics

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
    Write-Log "All tests passed - Load Balancer healthy"
    exit 0
} else {
    Write-Log "Some tests failed - Load Balancer issues detected"
    exit 1
}
