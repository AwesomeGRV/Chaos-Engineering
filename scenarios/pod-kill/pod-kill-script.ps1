# Pod Kill Chaos Experiment Script for Azure Kubernetes Service (AKS)
# This script simulates pod termination failures

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$true)]
    [string]$Namespace,
    
    [Parameter(Mandatory=$true)]
    [string]$LabelSelector,
    
    [Parameter(Mandatory=$false)]
    [int]$DurationMinutes = 5,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = "logs/pod-kill-experiment.log"
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
    
    # Check kubectl
    try {
        $kubectlVersion = kubectl version --client --short
        Write-Log "kubectl version: $kubectlVersion"
    }
    catch {
        Write-Log "kubectl not found. Please install kubectl." "ERROR"
        exit 1
    }
    
    # Check connection to AKS
    try {
        az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing
        $clusterInfo = kubectl cluster-info
        Write-Log "Connected to AKS cluster: $ClusterName"
    }
    catch {
        Write-Log "Failed to connect to AKS cluster." "ERROR"
        exit 1
    }
    
    Write-Log "Prerequisites validation completed."
}

# Get baseline metrics
function Get-BaselineMetrics {
    Write-Log "Collecting baseline metrics..."
    
    $baseline = @{}
    
    # Get pod count
    $podCount = kubectl get pods -n $Namespace -l $LabelSelector --no-headers | wc -l
    $baseline.PodCount = $podCount.Trim()
    
    # Get service endpoints
    $services = kubectl get services -n $Namespace -l $LabelSelector -o json
    $baseline.Services = $services
    
    # Get HPA status if exists
    try {
        $hpaStatus = kubectl get hpa -n $Namespace -l $LabelSelector -o json
        $baseline.HPA = $hpaStatus
    }
    catch {
        Write-Log "No HPA found for the specified selector."
    }
    
    return $baseline
}

# Execute pod kill chaos
function Invoke-PodKillChaos {
    Write-Log "Starting pod kill chaos experiment..."
    
    try {
        # Get target pods
        $targetPods = kubectl get pods -n $Namespace -l $LabelSelector -o jsonpath='{.items[*].metadata.name}'
        $podArray = $targetPods -split ' '
        
        Write-Log "Target pods identified: $($podArray.Count)"
        
        foreach ($pod in $podArray) {
            if ([string]::IsNullOrWhiteSpace($pod)) { continue }
            
            Write-Log "Deleting pod: $pod"
            kubectl delete pod $pod -n $Namespace --force --grace-period=0
            
            # Wait for pod recreation
            Write-Log "Waiting for pod recreation..."
            Start-Sleep -Seconds 30
            
            # Verify pod recreation
            $podStatus = kubectl get pod $pod -n $Namespace -o jsonpath='{.status.phase}' 2>$null
            if ($podStatus -eq "Running") {
                Write-Log "Pod $pod successfully recreated and running."
            } else {
                Write-Log "Pod $pod recreation status: $podStatus"
            }
        }
        
        Write-Log "Pod kill chaos experiment completed."
    }
    catch {
        Write-Log "Error during pod kill chaos: $_" "ERROR"
        throw
    }
}

# Monitor recovery
function Monitor-Recovery {
    param([hashtable]$Baseline)
    
    Write-Log "Monitoring system recovery..."
    $recoveryTime = 0
    $maxRecoveryTime = $DurationMinutes * 60
    
    do {
        Start-Sleep -Seconds 30
        $recoveryTime += 30
        
        # Check pod count
        $currentPodCount = kubectl get pods -n $Namespace -l $LabelSelector --no-headers | wc -l
        $currentPodCount = $currentPodCount.Trim()
        
        Write-Log "Recovery check - Time: ${recoveryTime}s, Pod count: $currentPodCount/$($Baseline.PodCount)"
        
        if ($currentPodCount -ge $Baseline.PodCount) {
            Write-Log "System recovered to baseline pod count."
            break
        }
        
    } while ($recoveryTime -lt $maxRecoveryTime)
    
    return $recoveryTime
}

# Generate experiment report
function New-ExperimentReport {
    param(
        [hashtable]$Baseline,
        [int]$RecoveryTime,
        [string]$Status
    )
    
    $report = @{
        Experiment = "Pod Kill Chaos"
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Duration = "$DurationMinutes minutes"
        Status = $Status
        Baseline = $Baseline
        RecoveryTimeSeconds = $RecoveryTime
        TargetNamespace = $Namespace
        TargetLabel = $LabelSelector
    }
    
    $reportPath = "reports/pod-kill-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath
    
    Write-Log "Experiment report saved to: $reportPath"
    return $reportPath
}

# Main execution
try {
    Write-Log "Starting Pod Kill Chaos Experiment"
    Write-Log "Parameters: RG=$ResourceGroup, Cluster=$ClusterName, Namespace=$Namespace, Label=$LabelSelector"
    
    # Create directories
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" }
    if (!(Test-Path "reports")) { New-Item -ItemType Directory -Path "reports" }
    
    # Execute experiment phases
    Test-Prerequisites
    $baseline = Get-BaselineMetrics
    Invoke-PodKillChaos
    $recoveryTime = Monitor-Recovery -Baseline $baseline
    
    # Generate report
    $status = if ($recoveryTime -lt ($DurationMinutes * 60)) { "Success" } else { "Partial" }
    $reportPath = New-ExperimentReport -Baseline $baseline -RecoveryTime $recoveryTime -Status $status
    
    Write-Log "Pod Kill Chaos Experiment completed successfully."
    Write-Log "Status: $status, Recovery Time: ${recoveryTime}s"
}
catch {
    Write-Log "Experiment failed: $_" "ERROR"
    exit 1
}
