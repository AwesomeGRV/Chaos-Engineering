# Azure Virtual Network Chaos Validation Script
# Validates VNet functionality during chaos experiments

param(
    [string]$ResourceGroup = "",
    [string]$VirtualNetworkName = "",
    [string]$TestVMName = "",
    [string]$TestSubnetName = "chaos-test-subnet"
)

# Install required modules
if (-not (Get-Module -ListAvailable -Name Az.Network)) {
    Install-Module -Name Az.Network -Force -Scope CurrentUser
}

# Initialize logging
$logPath = "C:\temp\virtual-network-chaos-validation.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $Message"
    Write-Host $Message
}

# Test Virtual Network basic connectivity
function Test-VNetConnectivity {
    Write-Log "Testing Virtual Network connectivity..."
    
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VirtualNetworkName
        Write-Log "✓ Virtual Network found: $($vnet.Name)"
        Write-Log "Location: $($vnet.Location)"
        Write-Log "Address space: $($vnet.AddressSpace.AddressPrefixes -join ', ')"
        Write-Log "Subnets: $($vnet.Subnets.Count)"
        
        foreach ($subnet in $vnet.Subnets) {
            Write-Log "  - $($subnet.Name): $($subnet.AddressPrefix)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Virtual Network connectivity failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Subnet connectivity and configuration
function Test-SubnetConnectivity {
    Write-Log "Testing Subnet connectivity and configuration..."
    
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VirtualNetworkName
        
        foreach ($subnet in $vnet.Subnets) {
            Write-Log "Testing subnet: $($subnet.Name)"
            
            # Check subnet configuration
            Write-Log "  - Address prefix: $($subnet.AddressPrefix)"
            Write-Log "  - Available IP addresses: $($subnet.IpConfigurations.Count) used"
            
            # Check NSG association
            if ($subnet.NetworkSecurityGroup) {
                Write-Log "  - NSG: $($subnet.NetworkSecurityGroup.Id)"
                $nsg = Get-AzNetworkSecurityGroup -ResourceId $subnet.NetworkSecurityGroup.Id
                Write-Log "    Security rules: $($nsg.SecurityRules.Count)"
            } else {
                Write-Log "  - No NSG associated"
            }
            
            # Check Route Table association
            if ($subnet.RouteTable) {
                Write-Log "  - Route Table: $($subnet.RouteTable.Id)"
                $routeTable = Get-AzRouteTable -ResourceId $subnet.RouteTable.Id
                Write-Log "    Routes: $($routeTable.Routes.Count)"
            } else {
                Write-Log "  - No Route Table associated"
            }
            
            # Check Service Endpoints
            if ($subnet.ServiceEndpoints) {
                Write-Log "  - Service Endpoints: $($subnet.ServiceEndpoints.Service -join ', ')"
            } else {
                Write-Log "  - No Service Endpoints"
            }
            
            # Check delegation
            if ($subnet.Delegations) {
                Write-Log "  - Delegations: $($subnet.Delegations.ServiceName)"
            } else {
                Write-Log "  - No delegations"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Subnet connectivity test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Network Security Groups
function Test-NetworkSecurityGroups {
    Write-Log "Testing Network Security Groups..."
    
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VirtualNetworkName
        $nsgs = @()
        
        # Collect all NSGs associated with the VNet
        foreach ($subnet in $vnet.Subnets) {
            if ($subnet.NetworkSecurityGroup) {
                $nsg = Get-AzNetworkSecurityGroup -ResourceId $subnet.NetworkSecurityGroup.Id
                $nsgs += $nsg
            }
        }
        
        Write-Log "✓ Found $($nsgs.Count) NSGs associated with VNet"
        
        foreach ($nsg in $nsgs) {
            Write-Log "NSG: $($nsg.Name)"
            
            # Check inbound rules
            $inboundRules = $nsg.SecurityRules | Where-Object { $_.Direction -eq "Inbound" }
            Write-Log "  Inbound rules: $($inboundRules.Count)"
            foreach ($rule in $inboundRules | Select-Object -First 5) {
                Write-Log "    - $($rule.Name): $($rule.Access) from $($rule.SourceAddressPrefix) to $($rule.DestinationPortRange)"
            }
            
            # Check outbound rules
            $outboundRules = $nsg.SecurityRules | Where-Object { $_.Direction -eq "Outbound" }
            Write-Log "  Outbound rules: $($outboundRules.Count)"
            foreach ($rule in $outboundRules | Select-Object -First 5) {
                Write-Log "    - $($rule.Name): $($rule.Access) to $($rule.DestinationAddressPrefix)"
            }
            
            # Check default rules
            $defaultRules = $nsg.DefaultSecurityRules
            Write-Log "  Default rules: $($defaultRules.Count)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Network Security Groups test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Route Tables
function Test-RouteTables {
    Write-Log "Testing Route Tables..."
    
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VirtualNetworkName
        $routeTables = @()
        
        # Collect all Route Tables associated with the VNet
        foreach ($subnet in $vnet.Subnets) {
            if ($subnet.RouteTable) {
                $routeTable = Get-AzRouteTable -ResourceId $subnet.RouteTable.Id
                $routeTables += $routeTable
            }
        }
        
        Write-Log "✓ Found $($routeTables.Count) Route Tables associated with VNet"
        
        foreach ($routeTable in $routeTables) {
            Write-Log "Route Table: $($routeTable.Name)"
            
            foreach ($route in $routeTable.Routes) {
                Write-Log "  - $($route.Name): $($route.AddressPrefix) via $($route.NextHopType)"
                if ($route.NextHopIpAddress) {
                    Write-Log "    Next Hop IP: $($route.NextHopIpAddress)"
                }
            }
            
            # Check BGP route propagation
            Write-Log "  BGP route propagation: $($routeTable.DisableBgpRoutePropagation)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Route Tables test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test VNet Peering
function Test-VNetPeering {
    Write-Log "Testing VNet Peering..."
    
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VirtualNetworkName
        $peerings = Get-AzVirtualNetworkPeering -VirtualNetworkName $VirtualNetworkName -ResourceGroupName $ResourceGroup
        
        if ($peerings.Count -gt 0) {
            Write-Log "✓ Found $($peerings.Count) VNet peerings"
            
            foreach ($peering in $peerings) {
                Write-Log "Peering: $($peering.Name)"
                Write-Log "  - Remote VNet: $($peering.RemoteVirtualNetwork)"
                Write-Log "  - Peering state: $($peering.PeeringState)"
                Write-Log "  - Allow forwarded traffic: $($peering.AllowForwardedTraffic)"
                Write-Log "  - Allow gateway transit: $($peering.AllowGatewayTransit)"
                Write-Log "  - Use remote gateways: $($peering.UseRemoteGateways)"
            }
        } else {
            Write-Log "⚠ No VNet peerings found"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ VNet Peering test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Private Endpoints
function Test-PrivateEndpoints {
    Write-Log "Testing Private Endpoints..."
    
    try {
        $privateEndpoints = Get-AzPrivateEndpoint -ResourceGroupName $ResourceGroup | Where-Object { $_.PrivateLinkServiceConnections.Count -gt 0 }
        
        if ($privateEndpoints.Count -gt 0) {
            Write-Log "✓ Found $($privateEndpoints.Count) Private Endpoints"
            
            foreach ($endpoint in $privateEndpoints) {
                Write-Log "Private Endpoint: $($endpoint.Name)"
                Write-Log "  - Subnet: $($endpoint.Subnet.Id)"
                Write-Log "  - Private IP: $($endpoint.CustomDnsConfigs.IpAddresses -join ', ')"
                
                foreach ($connection in $endpoint.PrivateLinkServiceConnections) {
                    Write-Log "  - Connected to: $($connection.PrivateLinkServiceId)"
                    Write-Log "    Status: $($connection.ProvisioningState)"
                }
            }
        } else {
            Write-Log "⚠ No Private Endpoints found"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Private Endpoints test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Network Watcher functionality
function Test-NetworkWatcher {
    Write-Log "Testing Network Watcher functionality..."
    
    try {
        # Find Network Watcher for the region
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VirtualNetworkName
        $networkWatcher = Get-AzNetworkWatcher | Where-Object { $_.Location -eq $vnet.Location }
        
        if ($networkWatcher) {
            Write-Log "✓ Network Watcher found: $($networkWatcher.Name)"
            
            # Test IP flow verify
            if ($TestVMName) {
                try {
                    $vm = Get-AzVM -ResourceGroupName $ResourceGroup -Name $TestVMName
                    $nic = Get-AzNetworkInterface -ResourceId $vm.NetworkInterfaceIDs[0]
                    
                    $flowVerify = Test-AzNetworkWatcherIPFlow -NetworkWatcher $networkWatcher -TargetVirtualMachineId $vm.Id -Direction "Inbound" -Protocol "TCP" -LocalIPAddress $nic.IpConfigurations[0].PrivateIpAddress -LocalPort 80 -RemoteIPAddress "8.8.8.8" -RemotePort 443
                    Write-Log "✓ IP Flow Verify test completed"
                    Write-Log "  - Access: $($flowVerify.Access)"
                    Write-Log "  - Rule name: $($flowVerify.RuleName)"
                }
                catch {
                    Write-Log "⚠ IP Flow Verify test failed: $($_.Exception.Message)"
                }
            }
            
            # Test next hop
            try {
                $nextHop = Get-AzNetworkWatcherNextHop -NetworkWatcher $networkWatcher -TargetVirtualMachineId $vm.Id -DestinationIPAddress "8.8.8.8"
                Write-Log "✓ Next Hop test completed"
                Write-Log "  - Next Hop Type: $($nextHop.NextHopType)"
                Write-Log "  - Next Hop IP: $($nextHop.NextHopIpAddress)"
            }
            catch {
                Write-Log "⚠ Next Hop test failed: $($_.Exception.Message)"
            }
            
        } else {
            Write-Log "⚠ No Network Watcher found for region $($vnet.Location)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Network Watcher test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test DNS resolution
function Test-DNSResolution {
    Write-Log "Testing DNS resolution..."
    
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VirtualNetworkName
        
        # Check custom DNS servers
        if ($vnet.DhcpOptions.DnsServers -and $vnet.DhcpOptions.DnsServers.Count -gt 0) {
            Write-Log "✓ Custom DNS servers configured: $($vnet.DhcpOptions.DnsServers -join ', ')"
        } else {
            Write-Log "✓ Using Azure-provided DNS"
        }
        
        # Test DNS resolution for internal services
        if ($TestVMName) {
            try {
                $vm = Get-AzVM -ResourceGroupName $ResourceGroup -Name $TestVMName
                $nic = Get-AzNetworkInterface -ResourceId $vm.NetworkInterfaceIDs[0]
                $privateIP = $nic.IpConfigurations[0].PrivateIpAddress
                
                # Test internal DNS resolution
                $dnsTest = Resolve-DnsName -Name $vm.Name -Type A -ErrorAction SilentlyContinue
                if ($dnsTest) {
                    Write-Log "✓ Internal DNS resolution successful for $($vm.Name)"
                } else {
                    Write-Log "⚠ Internal DNS resolution failed for $($vm.Name)"
                }
                
                # Test external DNS resolution
                $externalDnsTest = Resolve-DnsName -Name "google.com" -Type A -ErrorAction SilentlyContinue
                if ($externalDnsTest) {
                    Write-Log "✓ External DNS resolution successful"
                } else {
                    Write-Log "⚠ External DNS resolution failed"
                }
            }
            catch {
                Write-Log "⚠ DNS resolution test failed: $($_.Exception.Message)"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "✗ DNS resolution test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test VPN Gateway (if applicable)
function Test-VPNGateway {
    Write-Log "Testing VPN Gateway..."
    
    try {
        $vpnGateways = Get-AzVirtualNetworkGateway -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
        
        if ($vpnGateways.Count -gt 0) {
            Write-Log "✓ Found $($vpnGateways.Count) VPN Gateways"
            
            foreach ($gateway in $vpnGateways) {
                Write-Log "VPN Gateway: $($gateway.Name)"
                Write-Log "  - Type: $($gateway.GatewayType)"
                Write-Log "  - VPN Type: $($gateway.VpnType)"
                Write-Log "  - SKU: $($gateway.GatewaySku.Name)"
                Write-Log "  - Active connections: $($gateway.VpnClientConfiguration.VpnClientAddressPool.AddressPrefixes.Count)"
                
                # Check connections
                $connections = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $ResourceGroup | Where-Object { $_.VirtualNetworkGateway1.Id -eq $gateway.Id -or $_.VirtualNetworkGateway2.Id -eq $gateway.Id }
                Write-Log "  - Connections: $($connections.Count)"
                foreach ($connection in $connections) {
                    Write-Log "    - $($connection.Name): $($connection.ConnectionStatus)"
                }
            }
        } else {
            Write-Log "⚠ No VPN Gateways found"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ VPN Gateway test failed: $($_.Exception.Message)"
        return $false
    }
}

# Get Virtual Network metrics
function Get-VNetMetrics {
    Write-Log "Collecting Virtual Network metrics..."
    
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VirtualNetworkName
        $resourceId = $vnet.Id
        
        $metrics = @()
        
        # Flow log metrics
        try {
            $flowLogs = Get-AzNetworkWatcherFlowLog -TargetResourceId $resourceId -ErrorAction SilentlyContinue
            if ($flowLogs.Count -gt 0) {
                Write-Log "✓ Flow logs configured: $($flowLogs.Count)"
                $metrics += @{
                    Name = "FlowLogCount"
                    Value = $flowLogs.Count
                    Unit = "Count"
                }
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve flow log metrics"
        }
        
        # NSG metrics
        try {
            $nsgs = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroup
            $totalRules = 0
            foreach ($nsg in $nsgs) {
                $totalRules += $nsg.SecurityRules.Count + $nsg.DefaultSecurityRules.Count
            }
            $metrics += @{
                Name = "TotalNSGRules"
                Value = $totalRules
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve NSG metrics"
        }
        
        return $metrics
    }
    catch {
        Write-Log "✗ Failed to collect metrics: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
Write-Log "Starting Virtual Network chaos validation..."
Write-Log "Resource Group: $ResourceGroup"
Write-Log "Virtual Network: $VirtualNetworkName"
Write-Log "Test VM: $TestVMName"
Write-Log "Test Subnet: $TestSubnetName"

$testResults = @()

# Run all tests
$testResults += @{ Test = "Connectivity"; Result = (Test-VNetConnectivity) }
$testResults += @{ Test = "SubnetConnectivity"; Result = (Test-SubnetConnectivity) }
$testResults += @{ Test = "NetworkSecurityGroups"; Result = (Test-NetworkSecurityGroups) }
$testResults += @{ Test = "RouteTables"; Result = (Test-RouteTables) }
$testResults += @{ Test = "VNetPeering"; Result = (Test-VNetPeering) }
$testResults += @{ Test = "PrivateEndpoints"; Result = (Test-PrivateEndpoints) }
$testResults += @{ Test = "NetworkWatcher"; Result = (Test-NetworkWatcher) }
$testResults += @{ Test = "DNSResolution"; Result = (Test-DNSResolution) }
$testResults += @{ Test = "VPNGateway"; Result = (Test-VPNGateway) }

# Get metrics
$metrics = Get-VNetMetrics

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
    Write-Log "All tests passed - Virtual Network healthy"
    exit 0
} else {
    Write-Log "Some tests failed - Virtual Network issues detected"
    exit 1
}
