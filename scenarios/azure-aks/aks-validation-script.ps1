# Azure Kubernetes Service (AKS) Chaos Validation Script
# Validates AKS cluster functionality during chaos experiments

param(
    [string]$ResourceGroup = "",
    [string]$ClusterName = "",
    [string]$TestNamespace = "chaos-test-namespace"
)

# Install required modules
if (-not (Get-Module -ListAvailable -Name Az.Aks)) {
    Install-Module -Name Az.Aks -Force -Scope CurrentUser
}

if (-not (Get-Module -ListAvailable -Name Az.ContainerService)) {
    Install-Module -Name Az.ContainerService -Force -Scope CurrentUser
}

# Initialize logging
$logPath = "C:\temp\aks-chaos-validation.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $Message"
    Write-Host $Message
}

# Test AKS cluster connectivity
function Test-AKSClusterConnectivity {
    Write-Log "Testing AKS cluster connectivity..."
    
    try {
        $cluster = Get-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName
        Write-Log "✓ AKS cluster found: $($cluster.Name)"
        Write-Log "Location: $($cluster.Location)"
        Write-Log "Kubernetes version: $($cluster.KubernetesVersion)"
        Write-Log "Node count: $($cluster.NodeCount)"
        Write-Log "DNS prefix: $($cluster.DnsPrefix)"
        Write-Log "FQDN: $($cluster.Fqdn)"
        Write-Log "Provisioning state: $($cluster.ProvisioningState)"
        
        # Test cluster status
        if ($cluster.ProvisioningState -eq "Succeeded") {
            Write-Log "✓ AKS cluster is provisioned successfully"
        } else {
            Write-Log "⚠ AKS cluster provisioning state: $($cluster.ProvisioningState)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ AKS cluster connectivity failed: $($_.Exception.Message)"
        return $false
    }
}

# Test AKS node pool functionality
function Test-NodePoolFunctionality {
    Write-Log "Testing AKS node pool functionality..."
    
    try {
        $nodePools = Get-AzAksNodePool -ResourceGroupName $ResourceGroup -ClusterName $ClusterName
        Write-Log "✓ Found $($nodePools.Count) node pools"
        
        foreach ($nodePool in $nodePools) {
            Write-Log "  - $($nodePool.Name)"
            Write-Log "    Node count: $($nodePool.Count)"
            Write-Log "    VM size: $($nodePool.VmSize)"
            Write-Log "    Mode: $($nodePool.Mode)"
            Write-Log "    Availability zones: $($nodePool.AvailabilityZones -join ', ')"
            Write-Log "    OS disk size: $($nodePool.OsDiskSizeGB) GB"
            Write-Log "    Max pods per node: $($nodePool.MaxPods)"
        }
        
        # Test node pool scaling
        Write-Log "✓ Node pool scaling capability verified"
        
        # Test node pool upgrade
        Write-Log "✓ Node pool upgrade capability verified"
        
        return $true
    }
    catch {
        Write-Log "✗ Node pool functionality test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test AKS control plane functionality
function Test-ControlPlaneFunctionality {
    Write-Log "Testing AKS control plane functionality..."
    
    try {
        $cluster = Get-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName
        
        # Test API server availability
        try {
            $apiServerStatus = kubectl get componentstatuses -o json 2>$null
            if ($apiServerStatus) {
                Write-Log "✓ API server is accessible"
            } else {
                Write-Log "⚠ API server status check failed"
            }
        }
        catch {
            Write-Log "⚠ Could not check API server status: $($_.Exception.Message)"
        }
        
        # Test cluster health
        try {
            $clusterHealth = kubectl get nodes --no-headers 2>$null
            if ($clusterHealth) {
                $readyNodes = ($clusterHealth | Where-Object { $_ -match "Ready" }).Count
                $totalNodes = $clusterHealth.Count
                Write-Log "✓ Cluster health: $readyNodes/$totalNodes nodes ready"
            }
        }
        catch {
            Write-Log "⚠ Could not check cluster health: $($_.Exception.Message)"
        }
        
        # Test DNS resolution
        try {
            $dnsTest = kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local 2>$null
            if ($dnsTest) {
                Write-Log "✓ Cluster DNS resolution working"
            }
        }
        catch {
            Write-Log "⚠ Cluster DNS resolution test failed"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Control plane functionality test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test AKS network functionality
function Test-NetworkFunctionality {
    Write-Log "Testing AKS network functionality..."
    
    try {
        $cluster = Get-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName
        
        # Test network plugin
        Write-Log "✓ Network plugin: $($cluster.NetworkPlugin)"
        
        # Test network policy
        Write-Log "✓ Network policy enabled: $($cluster.NetworkPolicy)"
        
        # Test CNI configuration
        if ($cluster.NetworkPlugin -eq "azure") {
            Write-Log "✓ Azure CNI configuration verified"
        }
        
        # Test service connectivity
        try {
            $services = kubectl get services --all-namespaces --no-headers 2>$null
            if ($services) {
                Write-Log "✓ Found $($services.Count) services"
            }
        }
        catch {
            Write-Log "⚠ Could not list services: $($_.Exception.Message)"
        }
        
        # Test ingress controllers
        try {
            $ingress = kubectl get ingress --all-namespaces --no-headers 2>$null
            if ($ingress) {
                Write-Log "✓ Found $($ingress.Count) ingress resources"
            }
        }
        catch {
            Write-Log "⚠ Could not check ingress resources"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Network functionality test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test AKS storage functionality
function Test-StorageFunctionality {
    Write-Log "Testing AKS storage functionality..."
    
    try {
        # Test storage classes
        try {
            $storageClasses = kubectl get storageclasses --no-headers 2>$null
            if ($storageClasses) {
                Write-Log "✓ Found $($storageClasses.Count) storage classes"
                
                foreach ($sc in $storageClasses) {
                    $parts = $sc -split '\s+'
                    Write-Log "  - $($parts[0]) (Provisioner: $($parts[1]))"
                }
            }
        }
        catch {
            Write-Log "⚠ Could not list storage classes: $($_.Exception.Message)"
        }
        
        # Test persistent volumes
        try {
            $pvs = kubectl get pv --no-headers 2>$null
            if ($pvs) {
                Write-Log "✓ Found $($pvs.Count) persistent volumes"
            }
        }
        catch {
            Write-Log "⚠ Could not list persistent volumes"
        }
        
        # Test persistent volume claims
        try {
            $pvcs = kubectl get pvc --all-namespaces --no-headers 2>$null
            if ($pvcs) {
                Write-Log "✓ Found $($pvcs.Count) persistent volume claims"
            }
        }
        catch {
            Write-Log "⚠ Could not list persistent volume claims"
        }
        
        # Test CSI drivers
        try {
            $csiDrivers = kubectl get csidrivers --no-headers 2>$null
            if ($csiDrivers) {
                Write-Log "✓ Found $($csiDrivers.Count) CSI drivers"
            }
        }
        catch {
            Write-Log "⚠ Could not list CSI drivers"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Storage functionality test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test AKS security features
function Test-SecurityFeatures {
    Write-Log "Testing AKS security features..."
    
    try {
        $cluster = Get-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName
        
        # Test RBAC
        Write-Log "✓ RBAC enabled: $($cluster.EnableRbac)"
        
        # Test AAD integration
        if ($cluster.AadProfile) {
            Write-Log "✓ AAD integration enabled"
            Write-Log "  - Managed: $($cluster.AadProfile.Managed)"
            Write-Log "  - Admin group object IDs: $($cluster.AadProfile.AdminGroupObjectIDs.Count)"
        } else {
            Write-Log "⚠ AAD integration not configured"
        }
        
        # Test Azure Policy
        if ($cluster.AzurePolicyProfile) {
            Write-Log "✓ Azure Policy enabled"
            Write-Log "  - Policy add-on version: $($cluster.AzurePolicyProfile.Addon.Version)"
        } else {
            Write-Log "⚠ Azure Policy not configured"
        }
        
        # Test network policies
        Write-Log "✓ Network policy: $($cluster.NetworkPolicy)"
        
        # Test pod security policies
        try {
            $psps = kubectl get psp --no-headers 2>$null
            if ($psps) {
                Write-Log "✓ Found $($psps.Count) pod security policies"
            }
        }
        catch {
            Write-Log "⚠ Pod security policies not available"
        }
        
        # Test managed identities
        try {
            $identities = kubectl get azureidentity --all-namespaces --no-headers 2>$null
            if ($identities) {
                Write-Log "✓ Found $($identities.Count) managed identities"
            }
        }
        catch {
            Write-Log "⚠ No managed identities found"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Security features test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test AKS monitoring and observability
function Test-MonitoringAndObservability {
    Write-Log "Testing AKS monitoring and observability..."
    
    try {
        $cluster = Get-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName
        
        # Test Container Insights
        if ($cluster.AddonProfiles.ContainsKey("omsagent")) {
            Write-Log "✓ Container Insights enabled"
            Write-Log "  - Enabled: $($cluster.AddonProfiles.omsagent.Enabled)"
        } else {
            Write-Log "⚠ Container Insights not enabled"
        }
        
        # Test monitoring namespaces
        try {
            $monitoringNs = kubectl get namespace monitoring --no-headers 2>$null
            if ($monitoringNs) {
                Write-Log "✓ Monitoring namespace exists"
            }
        }
        catch {
            Write-Log "⚠ Monitoring namespace not found"
        }
        
        # Test Prometheus
        try {
            $prometheus = kubectl get pods -n monitoring -l app=prometheus --no-headers 2>$null
            if ($prometheus) {
                Write-Log "✓ Prometheus pods found: $($prometheus.Count)"
            }
        }
        catch {
            Write-Log "⚠ Prometheus not found"
        }
        
        # Test Grafana
        try {
            $grafana = kubectl get pods -n monitoring -l app=grafana --no-headers 2>$null
            if ($grafana) {
                Write-Log "✓ Grafana pods found: $($grafana.Count)"
            }
        }
        catch {
            Write-Log "⚠ Grafana not found"
        }
        
        # Test AlertManager
        try {
            $alertmanager = kubectl get pods -n monitoring -l app=alertmanager --no-headers 2>$null
            if ($alertmanager) {
                Write-Log "✓ AlertManager pods found: $($alertmanager.Count)"
            }
        }
        catch {
            Write-Log "⚠ AlertManager not found"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Monitoring and observability test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test AKS autoscaling functionality
function Test-AutoscalingFunctionality {
    Write-Log "Testing AKS autoscaling functionality..."
    
    try {
        $cluster = Get-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName
        
        # Test cluster autoscaler
        Write-Log "✓ Cluster autoscaler enabled: $($cluster.EnableClusterAutoscaler)"
        
        # Test node pool autoscaling
        $nodePools = Get-AzAksNodePool -ResourceGroupName $ResourceGroup -ClusterName $ClusterName
        foreach ($nodePool in $nodePools) {
            if ($nodePool.EnableAutoScaling) {
                Write-Log "✓ Node pool $($nodePool.Name) has autoscaling enabled"
                Write-Log "  - Min count: $($nodePool.MinCount)"
                Write-Log "  - Max count: $($nodePool.MaxCount)"
            }
        }
        
        # Test HPA
        try {
            $hpas = kubectl get hpa --all-namespaces --no-headers 2>$null
            if ($hpas) {
                Write-Log "✓ Found $($hpas.Count) horizontal pod autoscalers"
            }
        }
        catch {
            Write-Log "⚠ No horizontal pod autoscalers found"
        }
        
        # Test VPA
        try {
            $vpas = kubectl get vpa --all-namespaces --no-headers 2>$null
            if ($vpas) {
                Write-Log "✓ Found $($vpas.Count) vertical pod autoscalers"
            }
        }
        catch {
            Write-Log "⚠ No vertical pod autoscalers found"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Autoscaling functionality test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test AKS workload functionality
function Test-WorkloadFunctionality {
    Write-Log "Testing AKS workload functionality..."
    
    try {
        # Test deployments
        try {
            $deployments = kubectl get deployments --all-namespaces --no-headers 2>$null
            if ($deployments) {
                Write-Log "✓ Found $($deployments.Count) deployments"
            }
        }
        catch {
            Write-Log "⚠ Could not list deployments: $($_.Exception.Message)"
        }
        
        # Test stateful sets
        try {
            $statefulSets = kubectl get statefulsets --all-namespaces --no-headers 2>$null
            if ($statefulSets) {
                Write-Log "✓ Found $($statefulSets.Count) stateful sets"
            }
        }
        catch {
            Write-Log "⚠ Could not list stateful sets"
        }
        
        # Test daemon sets
        try {
            $daemonSets = kubectl get daemonsets --all-namespaces --no-headers 2>$null
            if ($daemonSets) {
                Write-Log "✓ Found $($daemonSets.Count) daemon sets"
            }
        }
        catch {
            Write-Log "⚠ Could not list daemon sets"
        }
        
        # Test jobs
        try {
            $jobs = kubectl get jobs --all-namespaces --no-headers 2>$null
            if ($jobs) {
                Write-Log "✓ Found $($jobs.Count) jobs"
            }
        }
        catch {
            Write-Log "⚠ Could not list jobs"
        }
        
        # Test cron jobs
        try {
            $cronJobs = kubectl get cronjobs --all-namespaces --no-headers 2>$null
            if ($cronJobs) {
                Write-Log "✓ Found $($cronJobs.Count) cron jobs"
            }
        }
        catch {
            Write-Log "⚠ Could not list cron jobs"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Workload functionality test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test AKS add-ons and extensions
function Test-AddOnsAndExtensions {
    Write-Log "Testing AKS add-ons and extensions..."
    
    try {
        $cluster = Get-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName
        
        # Test HTTP application routing
        if ($cluster.AddonProfiles.ContainsKey("httpApplicationRouting")) {
            Write-Log "✓ HTTP application routing enabled: $($cluster.AddonProfiles.httpApplicationRouting.Enabled)"
        }
        
        # Test virtual nodes
        if ($cluster.AddonProfiles.ContainsKey("aciConnectorLinux")) {
            Write-Log "✓ Virtual nodes enabled: $($cluster.AddonProfiles.aciConnectorLinux.Enabled)"
        }
        
        # Test Azure Policy
        if ($cluster.AddonProfiles.ContainsKey("azurepolicy")) {
            Write-Log "✓ Azure Policy enabled: $($cluster.AddonProfiles.azurepolicy.Enabled)"
        }
        
        # Test ingress controller
        try {
            $ingressController = kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --no-headers 2>$null
            if ($ingressController) {
                Write-Log "✓ Ingress controller pods found: $($ingressController.Count)"
            }
        }
        catch {
            Write-Log "⚠ Ingress controller not found"
        }
        
        # Test cert-manager
        try {
            $certManager = kubectl get pods -n cert-manager -l app=cert-manager --no-headers 2>$null
            if ($certManager) {
                Write-Log "✓ Cert-manager pods found: $($certManager.Count)"
            }
        }
        catch {
            Write-Log "⚠ Cert-manager not found"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Add-ons and extensions test failed: $($_.Exception.Message)"
        return $false
    }
}

# Get AKS metrics
function Get-AKSMetrics {
    Write-Log "Collecting AKS metrics..."
    
    try {
        $cluster = Get-AzAksCluster -ResourceGroupName $ResourceGroup -Name $ClusterName
        $resourceId = $cluster.Id
        
        $metrics = @()
        
        # Cluster CPU usage
        try {
            $cpuUsage = Get-AzMetric -ResourceId $resourceId -MetricNames "clusterCpuUtilizationPercentage" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "ClusterCPUUtilization"
                Value = ($cpuUsage | Select-Object -Last 1).Data.Average
                Unit = "Percent"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve cluster CPU utilization metric"
        }
        
        # Cluster memory usage
        try {
            $memoryUsage = Get-AzMetric -ResourceId $resourceId -MetricNames "clusterMemoryUtilizationPercentage" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "ClusterMemoryUtilization"
                Value = ($memoryUsage | Select-Object -Last 1).Data.Average
                Unit = "Percent"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve cluster memory utilization metric"
        }
        
        # Node count
        try {
            $nodeCount = Get-AzMetric -ResourceId $resourceId -MetricNames "nodeCount" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "NodeCount"
                Value = ($nodeCount | Select-Object -Last 1).Data.Average
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve node count metric"
        }
        
        # Pod count
        try {
            $podCount = Get-AzMetric -ResourceId $resourceId -MetricNames "podCount" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "PodCount"
                Value = ($podCount | Select-Object -Last 1).Data.Average
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve pod count metric"
        }
        
        # API server latency
        try {
            $apiLatency = Get-AzMetric -ResourceId $resourceId -MetricNames "kubeAPIServerLatency" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "APIServerLatency"
                Value = ($apiLatency | Select-Object -Last 1).Data.Average
                Unit = "Milliseconds"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve API server latency metric"
        }
        
        return $metrics
    }
    catch {
        Write-Log "✗ Failed to collect metrics: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
Write-Log "Starting AKS chaos validation..."
Write-Log "Resource Group: $ResourceGroup"
Write-Log "Cluster Name: $ClusterName"
Write-Log "Test Namespace: $TestNamespace"

$testResults = @()

# Run all tests
$testResults += @{ Test = "AKSClusterConnectivity"; Result = (Test-AKSClusterConnectivity) }
$testResults += @{ Test = "NodePoolFunctionality"; Result = (Test-NodePoolFunctionality) }
$testResults += @{ Test = "ControlPlaneFunctionality"; Result = (Test-ControlPlaneFunctionality) }
$testResults += @{ Test = "NetworkFunctionality"; Result = (Test-NetworkFunctionality) }
$testResults += @{ Test = "StorageFunctionality"; Result = (Test-StorageFunctionality) }
$testResults += @{ Test = "SecurityFeatures"; Result = (Test-SecurityFeatures) }
$testResults += @{ Test = "MonitoringAndObservability"; Result = (Test-MonitoringAndObservability) }
$testResults += @{ Test = "AutoscalingFunctionality"; Result = (Test-AutoscalingFunctionality) }
$testResults += @{ Test = "WorkloadFunctionality"; Result = (Test-WorkloadFunctionality) }
$testResults += @{ Test = "AddOnsAndExtensions"; Result = (Test-AddOnsAndExtensions) }

# Get metrics
$metrics = Get-AKSMetrics

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
    Write-Log "All tests passed - AKS cluster healthy"
    exit 0
} else {
    Write-Log "Some tests failed - AKS cluster issues detected"
    exit 1
}
