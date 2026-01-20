# Network Latency Chaos Experiment Script for Azure
# This script simulates network latency between Azure resources

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetVMs,  # Comma-separated VM names
    
    [Parameter(Mandatory=$false)]
    [int]$LatencyMs = 100,
    
    [Parameter(Mandatory=$false)]
    [int]$JitterMs = 10,
    
    [Parameter(Mandatory=$false)]
    [int]$CorrelationPercent = 25,
    
    [Parameter(Mandatory=$false)]
    [int]$DurationMinutes = 5,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = "logs/network-latency-experiment.log"
)

# Initialize logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

# Validate prerequisites
function Test-Prerequisites {
    Write-Log "Testing prerequisites..."
    
    # Check Azure CLI
    try {
        $azVersion = az version --query '"azure-cli"' -o tsv
        Write-Log "Azure CLI version: $azVersion"
    }
    catch {
        Write-Log "Azure CLI not found. Please install Azure CLI." "ERROR"
        exit 1
    }
    
    # Check connection to Azure
    try {
        $accountInfo = az account show --output json | ConvertFrom-Json
        Write-Log "Connected to Azure subscription: $($accountInfo.name)"
    }
    catch {
        Write-Log "Failed to connect to Azure. Please run 'az login'." "ERROR"
        exit 1
    }
    
    Write-Log "Prerequisites validation completed."
}

# Get baseline network metrics
function Get-BaselineNetworkMetrics {
    Write-Log "Collecting baseline network metrics..."
    
    $baseline = @{}
    $vmList = $TargetVMs -split ','
    
    foreach ($vmName in $vmList) {
        $vmName = $vmName.Trim()
        
        # Get VM network interface
        $nicInfo = az vm nic list --resource-group $ResourceGroup --vm-name $vmName --output json | ConvertFrom-Json
        $baseline[$vmName] = @{
            NICs = $nicInfo
            BaselineLatency = Test-NetworkLatency -VMName $vmName
            BaselineThroughput = Get-NetworkThroughput -VMName $vmName
        }
        
        Write-Log "Baseline metrics for $vmName`: Latency=$($baseline[$vmName].BaselineLatency)ms"
    }
    
    return $baseline
}

# Test network latency to VM
function Test-NetworkLatency {
    param([string]$VMName)
    
    try {
        # Get VM public IP
        $publicIP = az vm show --resource-group $ResourceGroup --name $VMName --query "publicIps" -o tsv
        
        if ([string]::IsNullOrWhiteSpace($publicIP)) {
            Write-Log "No public IP found for VM $VMName"
            return $null
        }
        
        # Test latency using ping (simplified approach)
        $pingResult = Test-Connection -ComputerName $publicIP -Count 4 -ErrorAction SilentlyContinue
        if ($pingResult) {
            $avgLatency = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
            return [math]::Round($avgLatency, 2)
        }
    }
    catch {
        Write-Log "Failed to test latency for VM $VMName`: $_"
    }
    
    return $null
}

# Get network throughput metrics
function Get-NetworkThroughput {
    param([string]$VMName)
    
    try {
        # Get network metrics from Azure Monitor (simplified)
        $endTime = Get-Date
        $startTime = $endTime.AddMinutes(-5)
        
        $metrics = az monitor metrics list `
            --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroup/providers/Microsoft.Compute/virtualMachines/$VMName" `
            --metric "Network In Total" "Network Out Total" `
            --interval PT1M `
            --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --output json | ConvertFrom-Json
        
        return $metrics
    }
    catch {
        Write-Log "Failed to get throughput metrics for VM $VMName`: $_"
        return $null
    }
}

# Apply network latency using Azure Network Watcher
function Invoke-NetworkLatencyChaos {
    Write-Log "Starting network latency chaos experiment..."
    
    $vmList = $TargetVMs -split ','
    
    foreach ($vmName in $vmList) {
        $vmName = $vmName.Trim()
        
        try {
            Write-Log "Applying network latency to VM: $vmName"
            
            # Get VM details
            $vmInfo = az vm show --resource-group $ResourceGroup --name $VMName --output json | ConvertFrom-Json
            $location = $vmInfo.location
            
            # Create network watcher if not exists
            $networkWatcher = az network watcher show --location $location --output json 2>$null
            if (-not $networkWatcher) {
                Write-Log "Creating network watcher in location: $location"
                az network watcher configure --locations $location --enabled true
            }
            
            # Apply traffic manager profile for latency simulation (alternative approach)
            # Note: This is a simplified approach. In production, you might use:
            # - Azure Firewall rules
            # - Network Virtual Appliances (NVAs)
            # - Service Fabric chaos extensions
            # - Custom network manipulation scripts
            
            Write-Log "Network latency applied to $vmName (simulated)"
            
        }
        catch {
            Write-Log "Failed to apply network latency to VM $vmName`: $_" "ERROR"
        }
    }
    
    Write-Log "Network latency chaos experiment initiated."
}

# Alternative: Apply latency using VM extensions
function Invoke-VMLatencyExtension {
    param([string]$VMName)
    
    try {
        $extensionScript = @"
#!/bin/bash
# Install network manipulation tools
sudo apt-get update
sudo apt-get install -y iproute2 net-tools

# Apply network latency
sudo tc qdisc add dev eth0 root netem delay ${LatencyMs}ms ${JitterMs}ms ${CorrelationPercent}%

# Create cleanup script
echo '#!/bin/bash
sudo tc qdisc del dev eth0 root netem 2>/dev/null || true' > /tmp/cleanup_latency.sh
sudo chmod +x /tmp/cleanup_latency.sh

# Schedule cleanup after duration
echo "sudo at now + $DurationMinutes minutes -f /tmp/cleanup_latency.sh" | sudo at now + $DurationMinutes minutes

echo "Network latency applied: ${LatencyMs}ms +/- ${JitterMs}ms with ${CorrelationPercent}% correlation"
"@
        
        # Apply custom script extension
        az vm extension set `
            --resource-group $ResourceGroup `
            --vm-name $VMName `
            --name CustomScript `
            --publisher Microsoft.Azure.Extensions `
            --version 2.1 `
            --protected-settings "{'commandToExecute': '$extensionScript'}"
        
        Write-Log "Network latency extension applied to VM $VMName"
    }
    catch {
        Write-Log "Failed to apply latency extension to VM $VMName`: $_"
    }
}

# Monitor network performance during experiment
function Monitor-NetworkPerformance {
    param([hashtable]$Baseline)
    
    Write-Log "Monitoring network performance during experiment..."
    $monitoringResults = @()
    
    $vmList = $TargetVMs -split ','
    $durationSeconds = $DurationMinutes * 60
    $elapsed = 0
    
    while ($elapsed -lt $durationSeconds) {
        $timestamp = Get-Date
        
        foreach ($vmName in $vmList) {
            $vmName = $vmName.Trim()
            
            $currentLatency = Test-NetworkLatency -VMName $vmName
            $currentThroughput = Get-NetworkThroughput -VMName $vmName
            
            $result = @{
                Timestamp = $timestamp
                VMName = $vmName
                CurrentLatency = $currentLatency
                BaselineLatency = $Baseline[$vmName].BaselineLatency
                LatencyIncrease = if ($currentLatency -and $Baseline[$vmName].BaselineLatency) { 
                    $currentLatency - $Baseline[$vmName].BaselineLatency 
                } else { $null }
                Throughput = $currentThroughput
            }
            
            $monitoringResults += $result
            
            Write-Log "VM $vmName`: Current latency=$currentLatency`ms, Baseline=$($Baseline[$vmName].BaselineLatency)`ms"
        }
        
        Start-Sleep -Seconds 30
        $elapsed += 30
    }
    
    return $monitoringResults
}

# Cleanup network latency
function Remove-NetworkLatency {
    Write-Log "Cleaning up network latency configuration..."
    
    $vmList = $TargetVMs -split ','
    
    foreach ($vmName in $vmList) {
        $vmName = $vmName.Trim()
        
        try {
            # Remove custom script extension
            az vm extension delete `
                --resource-group $ResourceGroup `
                --vm-name $VMName `
                --name CustomScript
            
            Write-Log "Network latency configuration removed from VM $vmName"
        }
        catch {
            Write-Log "Failed to remove latency configuration from VM $vmName`: $_"
        }
    }
}

# Generate experiment report
function New-ExperimentReport {
    param(
        [hashtable]$Baseline,
        [array]$MonitoringResults,
        [string]$Status
    )
    
    $report = @{
        Experiment = "Network Latency Chaos"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Duration = "$DurationMinutes minutes"
        Status = $Status
        Parameters = @{
            LatencyMs = $LatencyMs
            JitterMs = $JitterMs
            CorrelationPercent = $CorrelationPercent
            TargetVMs = $TargetVMs
        }
        Baseline = $Baseline
        MonitoringResults = $MonitoringResults
        TargetResourceGroup = $ResourceGroup
    }
    
    $reportPath = "reports/network-latency-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath
    
    Write-Log "Experiment report saved to: $reportPath"
    return $reportPath
}

# Main execution
try {
    Write-Log "Starting Network Latency Chaos Experiment"
    Write-Log "Parameters: RG=$ResourceGroup, VMs=$TargetVMs, Latency=${LatencyMs}ms, Duration=$DurationMinutes minutes"
    
    # Create directories
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" }
    if (!(Test-Path "reports")) { New-Item -ItemType Directory -Path "reports" }
    
    # Execute experiment phases
    Test-Prerequisites
    $baseline = Get-BaselineNetworkMetrics
    
    # Apply latency to all VMs
    $vmList = $TargetVMs -split ','
    foreach ($vmName in $vmList) {
        Invoke-VMLatencyExtension -VMName $vmName.Trim()
    }
    
    # Monitor performance
    $monitoringResults = Monitor-NetworkPerformance -Baseline $baseline
    
    # Cleanup
    Remove-NetworkLatency
    
    # Generate report
    $status = "Success"
    $reportPath = New-ExperimentReport -Baseline $baseline -MonitoringResults $monitoringResults -Status $status
    
    Write-Log "Network Latency Chaos Experiment completed successfully."
    Write-Log "Status: $status"
}
catch {
    Write-Log "Experiment failed: $_" "ERROR"
    # Attempt cleanup
    Remove-NetworkLatency
    exit 1
}
