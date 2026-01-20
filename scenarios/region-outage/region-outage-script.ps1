# Region Outage Chaos Experiment Script for Azure
# This script simulates a regional Azure service outage

param(
    [Parameter(Mandatory=$true)]
    [string]$PrimaryResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$SecondaryResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$TrafficManagerProfile,
    
    [Parameter(Mandatory=$true)]
    [string]$PrimaryRegion,
    
    [Parameter(Mandatory=$true)]
    [string]$SecondaryRegion,
    
    [Parameter(Mandatory=$false)]
    [int]$DurationMinutes = 10,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = "logs/region-outage-experiment.log"
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
    
    # Verify Traffic Manager profile exists
    try {
        $tmProfile = az network traffic-manager profile show `
            --name $TrafficManagerProfile `
            --resource-group $PrimaryResourceGroup `
            --output json | ConvertFrom-Json
        Write-Log "Traffic Manager profile found: $($tmProfile.name)"
    }
    catch {
        Write-Log "Traffic Manager profile not found." "ERROR"
        exit 1
    }
    
    Write-Log "Prerequisites validation completed."
}

# Get baseline metrics for both regions
function Get-BaselineMetrics {
    Write-Log "Collecting baseline metrics..."
    
    $baseline = @{
        PrimaryRegion = @{
            ResourceGroup = $PrimaryResourceGroup
            Region = $PrimaryRegion
            Services = @{}
            HealthChecks = @{}
            TrafficMetrics = @{}
        }
        SecondaryRegion = @{
            ResourceGroup = $SecondaryResourceGroup
            Region = $SecondaryRegion
            Services = @{}
            HealthChecks = @{}
            TrafficMetrics = @{}
        }
        TrafficManager = @{
            Profile = $TrafficManagerProfile
            Endpoints = @{}
            RoutingMethod = ""
        }
    }
    
    # Get Traffic Manager configuration
    $tmConfig = az network traffic-manager profile show `
        --name $TrafficManagerProfile `
        --resource-group $PrimaryResourceGroup `
        --output json | ConvertFrom-Json
    
    $baseline.TrafficManager.RoutingMethod = $tmConfig.trafficRoutingMethod
    
    # Get Traffic Manager endpoints
    $endpoints = az network traffic-manager endpoint list `
        --profile-name $TrafficManagerProfile `
        --resource-group $PrimaryResourceGroup `
        --output json | ConvertFrom-Json
    
    foreach ($endpoint in $endpoints) {
        $baseline.TrafficManager.Endpoints[$endpoint.name] = @{
            Target = $endpoint.properties.target
            Priority = $endpoint.properties.priority
            Status = $endpoint.properties.endpointStatus
            Location = $endpoint.properties.endpointLocation
        }
    }
    
    # Get health status of endpoints
    foreach ($endpoint in $endpoints) {
        $healthCheck = az network traffic-manager endpoint check-health `
            --name $endpoint.name `
            --profile-name $TrafficManagerProfile `
            --resource-group $PrimaryResourceGroup `
            --output json | ConvertFrom-Json
        
        $baseline.TrafficManager.Endpoints[$endpoint.name].Health = $healthCheck
        Write-Log "Endpoint $($endpoint.name) health: $($healthCheck)"
    }
    
    # Get baseline metrics for primary region
    $baseline.PrimaryRegion.Services = Get-RegionServices -ResourceGroup $PrimaryResourceGroup
    $baseline.PrimaryRegion.HealthChecks = Get-HealthCheckMetrics -ResourceGroup $PrimaryResourceGroup
    
    # Get baseline metrics for secondary region
    $baseline.SecondaryRegion.Services = Get-RegionServices -ResourceGroup $SecondaryResourceGroup
    $baseline.SecondaryRegion.HealthChecks = Get-HealthCheckMetrics -ResourceGroup $SecondaryResourceGroup
    
    return $baseline
}

# Get services in a region
function Get-RegionServices {
    param([string]$ResourceGroup)
    
    $services = @{}
    
    try {
        # Get App Services
        $appServices = az webapp list --resource-group $ResourceGroup --output json | ConvertFrom-Json
        $services.AppServices = $appServices
        
        # Get Virtual Machines
        $vms = az vm list --resource-group $ResourceGroup --output json | ConvertFrom-Json
        $services.VirtualMachines = $vms
        
        # Get Storage Accounts
        $storageAccounts = az storage account list --resource-group $ResourceGroup --output json | ConvertFrom-Json
        $services.StorageAccounts = $storageAccounts
        
        # Get Azure SQL databases
        $sqlServers = az sql server list --resource-group $ResourceGroup --output json | ConvertFrom-Json
        $services.SQLServers = $sqlServers
        
        Write-Log "Found $($appServices.Count) App Services, $($vms.Count) VMs, $($storageAccounts.Count) Storage Accounts in $ResourceGroup"
    }
    catch {
        Write-Log "Error getting services for $ResourceGroup`: $_"
    }
    
    return $services
}

# Get health check metrics
function Get-HealthCheckMetrics {
    param([string]$ResourceGroup)
    
    $healthMetrics = @{}
    
    try {
        # Get Application Insights metrics if available
        $appInsights = az monitor app-insights component list --resource-group $ResourceGroup --output json | ConvertFrom-Json
        
        foreach ($appInsight in $appInsights) {
            $endTime = Get-Date
            $startTime = $endTime.AddMinutes(-5)
            
            $metrics = az monitor metrics list `
                --resource $appInsight.id `
                --metric "availabilityResults/availabilityPercentage" "requests/count" "exceptions/count" `
                --interval PT1M `
                --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
                --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
                --output json | ConvertFrom-Json
            
            $healthMetrics[$appInsight.name] = $metrics
        }
    }
    catch {
        Write-Log "Error getting health metrics for $ResourceGroup`: $_"
    }
    
    return $healthMetrics
}

# Simulate region outage by disabling Traffic Manager endpoint
function Invoke-RegionOutageChaos {
    Write-Log "Starting region outage simulation..."
    
    try {
        # Find primary region endpoint
        $endpoints = az network traffic-manager endpoint list `
            --profile-name $TrafficManagerProfile `
            --resource-group $PrimaryResourceGroup `
            --output json | ConvertFrom-Json
        
        $primaryEndpoint = $endpoints | Where-Object { 
            $_.properties.endpointLocation -eq $PrimaryRegion -and 
            $_.properties.endpointStatus -eq "Enabled" 
        } | Select-Object -First 1
        
        if (-not $primaryEndpoint) {
            Write-Log "No enabled endpoint found for primary region $PrimaryRegion" "ERROR"
            throw "Primary region endpoint not found"
        }
        
        Write-Log "Disabling primary region endpoint: $($primaryEndpoint.name)"
        
        # Disable the primary endpoint
        az network traffic-manager endpoint update `
            --name $primaryEndpoint.name `
            --profile-name $TrafficManagerProfile `
            --resource-group $PrimaryResourceGroup `
            --endpoint-status Disabled
        
        Write-Log "Primary region endpoint disabled. Traffic will now route to secondary region."
        
        # Wait for DNS propagation and failover
        Write-Log "Waiting for traffic failover to complete..."
        Start-Sleep -Seconds 60
        
        # Verify failover
        $failoverHealth = az network traffic-manager endpoint check-health `
            --name $primaryEndpoint.name `
            --profile-name $TrafficManagerProfile `
            --resource-group $PrimaryResourceGroup `
            --output json | ConvertFrom-Json
        
        Write-Log "Primary endpoint health after disable: $failoverHealth"
        
        return $primaryEndpoint.name
    }
    catch {
        Write-Log "Failed to simulate region outage: $_" "ERROR"
        throw
    }
}

# Monitor system behavior during outage
function Monitor-OutageBehavior {
    param([hashtable]$Baseline, [string]$DisabledEndpoint)
    
    Write-Log "Monitoring system behavior during region outage..."
    $monitoringResults = @()
    
    $durationSeconds = $DurationMinutes * 60
    $elapsed = 0
    
    while ($elapsed -lt $durationSeconds) {
        $timestamp = Get-Date
        
        # Check Traffic Manager endpoint health
        $endpoints = az network traffic-manager endpoint list `
            --profile-name $TrafficManagerProfile `
            --resource-group $PrimaryResourceGroup `
            --output json | ConvertFrom-Json
        
        $endpointStatuses = @{}
        foreach ($endpoint in $endpoints) {
            $health = az network traffic-manager endpoint check-health `
                --name $endpoint.name `
                --profile-name $TrafficManagerProfile `
                --resource-group $PrimaryResourceGroup `
                --output json | ConvertFrom-Json
            
            $endpointStatuses[$endpoint.name] = @{
                Status = $endpoint.properties.endpointStatus
                Health = $health
                Location = $endpoint.properties.endpointLocation
            }
        }
        
        # Check secondary region health
        $secondaryHealth = Get-HealthCheckMetrics -ResourceGroup $SecondaryResourceGroup
        
        # Test external connectivity (if domain is available)
        $externalConnectivity = Test-ExternalConnectivity
        
        $result = @{
            Timestamp = $timestamp
            ElapsedSeconds = $elapsed
            EndpointStatuses = $endpointStatuses
            SecondaryRegionHealth = $secondaryHealth
            ExternalConnectivity = $externalConnectivity
        }
        
        $monitoringResults += $result
        
        Write-Log "Outage monitoring - Time: ${elapsed}s, External connectivity: $externalConnectivity"
        
        Start-Sleep -Seconds 30
        $elapsed += 30
    }
    
    return $monitoringResults
}

# Test external connectivity to the service
function Test-ExternalConnectivity {
    try {
        # This would typically test your actual service endpoint
        # For demonstration, we'll simulate the check
        $tmProfile = az network traffic-manager profile show `
            --name $TrafficManagerProfile `
            --resource-group $PrimaryResourceGroup `
            --output json | ConvertFrom-Json
        
        $dnsName = $tmProfile.dnsConfig.relativeName + ".trafficmanager.net"
        
        # Test DNS resolution
        try {
            $resolvedIPs = Resolve-DnsName -Name $dnsName -ErrorAction SilentlyContinue
            if ($resolvedIPs) {
                return "Available"
            } else {
                return "DNS Resolution Failed"
            }
        }
        catch {
            return "DNS Resolution Failed"
        }
    }
    catch {
        return "Unknown"
    }
}

# Restore primary region endpoint
function Restore-RegionOutage {
    param([string]$DisabledEndpoint)
    
    Write-Log "Restoring primary region endpoint..."
    
    try {
        az network traffic-manager endpoint update `
            --name $DisabledEndpoint `
            --profile-name $TrafficManagerProfile `
            --resource-group $PrimaryResourceGroup `
            --endpoint-status Enabled
        
        Write-Log "Primary region endpoint restored."
        
        # Wait for restoration
        Start-Sleep -Seconds 30
        
        # Verify restoration
        $health = az network traffic-manager endpoint check-health `
            --name $DisabledEndpoint `
            --profile-name $TrafficManagerProfile `
            --resource-group $PrimaryResourceGroup `
            --output json | ConvertFrom-Json
        
        Write-Log "Primary endpoint health after restoration: $health"
        
        return $health
    }
    catch {
        Write-Log "Failed to restore primary region endpoint: $_" "ERROR"
        throw
    }
}

# Generate experiment report
function New-ExperimentReport {
    param(
        [hashtable]$Baseline,
        [array]$MonitoringResults,
        [string]$DisabledEndpoint,
        [string]$Status
    )
    
    $report = @{
        Experiment = "Region Outage Chaos"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Duration = "$DurationMinutes minutes"
        Status = $Status
        Parameters = @{
            PrimaryRegion = $PrimaryRegion
            SecondaryRegion = $SecondaryRegion
            PrimaryResourceGroup = $PrimaryResourceGroup
            SecondaryResourceGroup = $SecondaryResourceGroup
            TrafficManagerProfile = $TrafficManagerProfile
            DisabledEndpoint = $DisabledEndpoint
        }
        Baseline = $Baseline
        MonitoringResults = $MonitoringResults
        FailoverTime = if ($MonitoringResults.Count -gt 0) { $MonitoringResults[0].Timestamp } else { $null }
        RecoveryTime = if ($MonitoringResults.Count -gt 0) { $MonitoringResults[-1].Timestamp } else { $null }
    }
    
    $reportPath = "reports/region-outage-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath
    
    Write-Log "Experiment report saved to: $reportPath"
    return $reportPath
}

# Main execution
try {
    Write-Log "Starting Region Outage Chaos Experiment"
    Write-Log "Parameters: Primary RG=$PrimaryResourceGroup ($PrimaryRegion), Secondary RG=$SecondaryResourceGroup ($SecondaryRegion), TM=$TrafficManagerProfile"
    
    # Create directories
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" }
    if (!(Test-Path "reports")) { New-Item -ItemType Directory -Path "reports" }
    
    # Execute experiment phases
    Test-Prerequisites
    $baseline = Get-BaselineMetrics
    $disabledEndpoint = Invoke-RegionOutageChaos
    $monitoringResults = Monitor-OutageBehavior -Baseline $baseline -DisabledEndpoint $disabledEndpoint
    Restore-RegionOutage -DisabledEndpoint $disabledEndpoint
    
    # Generate report
    $status = "Success"
    $reportPath = New-ExperimentReport -Baseline $baseline -MonitoringResults $monitoringResults -DisabledEndpoint $disabledEndpoint -Status $status
    
    Write-Log "Region Outage Chaos Experiment completed successfully."
    Write-Log "Status: $status"
}
catch {
    Write-Log "Experiment failed: $_" "ERROR"
    # Attempt restoration
    if ($disabledEndpoint) {
        try {
            Restore-RegionOutage -DisabledEndpoint $disabledEndpoint
        } catch {
            Write-Log "Failed to restore endpoint during cleanup: $_" "ERROR"
        }
    }
    exit 1
}
