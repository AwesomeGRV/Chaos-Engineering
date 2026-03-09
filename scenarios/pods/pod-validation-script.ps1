# Kubernetes Pod Chaos Validation Script
# Validates pod health and functionality during chaos experiments

param(
    [string]$Namespace = "production",
    [string]$LabelSelector = "",
    [string]$KubeConfigPath = ""
)

# Install required modules
if (-not (Get-Module -ListAvailable -Name Kubernetes)) {
    Install-Module -Name Kubernetes -Force -Scope CurrentUser
}

# Initialize logging
$logPath = "C:\temp\pod-chaos-validation.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $Message"
    Write-Host $Message
}

# Connect to Kubernetes cluster
function Connect-KubernetesCluster {
    Write-Log "Connecting to Kubernetes cluster..."
    
    try {
        if ($KubeConfigPath) {
            Set-KubeConfig -Path $KubeConfigPath
        }
        
        # Test connection
        $nodes = Get-KubeNode
        Write-Log "✓ Connected to cluster with $($nodes.Count) nodes"
        
        return $true
    }
    catch {
        Write-Log "✗ Failed to connect to Kubernetes cluster: $($_.Exception.Message)"
        return $false
    }
}

# Test pod health and status
function Test-PodHealth {
    Write-Log "Testing pod health and status..."
    
    try {
        $selector = if ($LabelSelector) { "-l $LabelSelector" } else { "" }
        $pods = Get-KubePod -Namespace $Namespace $selector
        
        if ($pods.Count -eq 0) {
            Write-Log "⚠ No pods found with selector '$LabelSelector' in namespace '$Namespace'"
            return $true
        }
        
        $healthyPods = 0
        $totalPods = $pods.Count
        
        foreach ($pod in $pods) {
            $status = $pod.Status.Phase
            $ready = ($pod.Status.ContainerStatuses | Where-Object { $_.Ready -eq $true }).Count
            $total = $pod.Status.ContainerStatuses.Count
            
            if ($status -eq "Running" -and $ready -eq $total) {
                $healthyPods++
                Write-Log "✓ Pod $($pod.Name): $status ($ready/$total containers ready)"
            } else {
                Write-Log "✗ Pod $($pod.Name): $status ($ready/$total containers ready)"
                
                # Check for issues
                foreach ($containerStatus in $pod.Status.ContainerStatuses) {
                    if (-not $containerStatus.Ready) {
                        $state = $containerStatus.State
                        if ($state.Waiting) {
                            Write-Log "  - Container $($containerStatus.Name): Waiting - $($state.Waiting.Reason)"
                        }
                        if ($state.Terminated) {
                            Write-Log "  - Container $($containerStatus.Name): Terminated - $($state.Terminated.Reason)"
                        }
                    }
                }
            }
        }
        
        $healthPercentage = ($healthyPods / $totalPods) * 100
        Write-Log "Pod health: $healthyPods/$totalPods ($([math]::Round($healthPercentage, 2))%)"
        
        if ($healthPercentage -ge 80) {
            return $true
        } else {
            return $false
        }
    }
    catch {
        Write-Log "✗ Pod health check failed: $($_.Exception.Message)"
        return $false
    }
}

# Test pod restart behavior
function Test-PodRestarts {
    Write-Log "Testing pod restart behavior..."
    
    try {
        $selector = if ($LabelSelector) { "-l $LabelSelector" } else { "" }
        $pods = Get-KubePod -Namespace $Namespace $selector
        
        $totalRestarts = 0
        $podsWithRestarts = 0
        
        foreach ($pod in $pods) {
            $podRestarts = 0
            foreach ($containerStatus in $pod.Status.ContainerStatuses) {
                $podRestarts += $containerStatus.RestartCount
            }
            
            if ($podRestarts -gt 0) {
                $podsWithRestarts++
                $totalRestarts += $podRestarts
                Write-Log "Pod $($pod.Name): $podRestarts restart(s)"
            }
        }
        
        if ($podsWithRestarts -gt 0) {
            $avgRestarts = $totalRestarts / $podsWithRestarts
            Write-Log "Average restarts per affected pod: $([math]::Round($avgRestarts, 2))"
            
            if ($avgRestarts -lt 3) {
                Write-Log "✓ Pod restart behavior within acceptable limits"
                return $true
            } else {
                Write-Log "✗ High pod restart rate detected"
                return $false
            }
        } else {
            Write-Log "✓ No pod restarts detected"
            return $true
        }
    }
    catch {
        Write-Log "✗ Pod restart check failed: $($_.Exception.Message)"
        return $false
    }
}

# Test pod resource usage
function Test-PodResources {
    Write-Log "Testing pod resource usage..."
    
    try {
        $selector = if ($LabelSelector) { "-l $LabelSelector" } else { "" }
        $pods = Get-KubePod -Namespace $Namespace $selector
        
        $resourceIssues = 0
        
        foreach ($pod in $pods) {
            # Get pod metrics (requires metrics server)
            try {
                $metrics = kubectl top pod $pod.Name -n $Namespace --no-headers 2>$null
                if ($metrics) {
                    $parts = $metrics -split '\s+'
                    $cpuCores = $parts[1]
                    $memoryMB = $parts[2]
                    
                    # Convert to numeric values
                    $cpuCores = [double]($cpuCores -replace 'm', '') / 1000
                    $memoryMB = [double]($memoryMB -replace 'Mi', '')
                    
                    Write-Log "Pod $($pod.Name): CPU=$cpuCores cores, Memory=$memoryMB MB"
                    
                    # Check for resource pressure (adjust thresholds as needed)
                    if ($cpuCores -gt 2.0 -or $memoryMB -gt 2048) {
                        $resourceIssues++
                        Write-Log "⚠ High resource usage detected for pod $($pod.Name)"
                    }
                }
            }
            catch {
                Write-Log "⚠ Could not retrieve metrics for pod $($pod.Name)"
            }
        }
        
        if ($resourceIssues -eq 0) {
            Write-Log "✓ Pod resource usage within acceptable limits"
            return $true
        } else {
            Write-Log "✗ Resource pressure detected in $resourceIssues pod(s)"
            return $false
        }
    }
    catch {
        Write-Log "✗ Pod resource check failed: $($_.Exception.Message)"
        return $false
    }
}

# Test pod network connectivity
function Test-PodNetwork {
    Write-Log "Testing pod network connectivity..."
    
    try {
        $selector = if ($LabelSelector) { "-l $LabelSelector" } else { "" }
        $pods = Get-KubePod -Namespace $Namespace $selector
        
        if ($pods.Count -eq 0) {
            Write-Log "⚠ No pods found for network testing"
            return $true
        }
        
        $testPod = $pods[0]
        
        # Test internal connectivity
        try {
            $result = kubectl exec $testPod.Name -n $Namespace -- ping -c 3 kubernetes.default.svc.cluster.local 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "✓ Internal DNS resolution working"
            } else {
                Write-Log "✗ Internal DNS resolution failed"
                return $false
            }
        }
        catch {
            Write-Log "✗ Network connectivity test failed: $($_.Exception.Message)"
            return $false
        }
        
        # Test external connectivity
        try {
            $result = kubectl exec $testPod.Name -n $Namespace -- ping -c 1 8.8.8.8 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "✓ External connectivity working"
            } else {
                Write-Log "⚠ External connectivity may be restricted (this could be intentional)"
            }
        }
        catch {
            Write-Log "⚠ External connectivity test failed (this could be intentional)"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Pod network test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test pod readiness and liveness probes
function Test-PodProbes {
    Write-Log "Testing pod readiness and liveness probes..."
    
    try {
        $selector = if ($LabelSelector) { "-l $LabelSelector" } else { "" }
        $pods = Get-KubePod -Namespace $Namespace $selector
        
        $podsWithProbes = 0
        $probeIssues = 0
        
        foreach ($pod in $pods) {
            $podSpec = kubectl get pod $pod.Name -n $Namespace -o jsonpath='{.spec.containers[*].readinessProbe}' 2>$null
            $livenessSpec = kubectl get pod $pod.Name -n $Namespace -o jsonpath='{.spec.containers[*].livenessProbe}' 2>$null
            
            if ($podSpec -or $livenessSpec) {
                $podsWithProbes++
                
                # Check probe status
                foreach ($containerStatus in $pod.Status.ContainerStatuses) {
                    if ($containerStatus.Ready) {
                        Write-Log "✓ Pod $($pod.Name) containers ready"
                    } else {
                        $probeIssues++
                        Write-Log "✗ Pod $($pod.Name) container not ready"
                    }
                }
            }
        }
        
        if ($podsWithProbes -gt 0) {
            Write-Log "✓ $podsWithProbes pod(s) have health probes configured"
            
            if ($probeIssues -eq 0) {
                Write-Log "✓ All health probes passing"
                return $true
            } else {
                Write-Log "✗ $probeIssues probe issues detected"
                return $false
            }
        } else {
            Write-Log "⚠ No health probes configured"
            return $true
        }
    }
    catch {
        Write-Log "✗ Pod probe test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test pod scaling behavior
function Test-PodScaling {
    Write-Log "Testing pod scaling behavior..."
    
    try {
        # Check for deployments, replicasets, or statefulsets
        $deployments = kubectl get deployment -n $Namespace -l $LabelSelector --no-headers 2>$null
        $replicasets = kubectl get replicaset -n $Namespace -l $LabelSelector --no-headers 2>$null
        $statefulsets = kubectl get statefulset -n $Namespace -l $LabelSelector --no-headers 2>$null
        
        $scalingResources = @()
        
        if ($deployments) {
            $scalingResources += "Deployments"
        }
        if ($replicasets) {
            $scalingResources += "ReplicaSets"
        }
        if ($statefulsets) {
            $scalingResources += "StatefulSets"
        }
        
        if ($scalingResources.Count -gt 0) {
            Write-Log "✓ Scaling resources found: $($scalingResources -join ', ')"
            
            # Check desired vs available replicas
            foreach ($deployment in $deployments -split '\n') {
                $parts = $deployment -split '\s+'
                $name = $parts[0]
                $ready = $parts[1]
                $desired = $parts[2]
                
                if ($ready -eq $desired) {
                    Write-Log "✓ Deployment $name: $ready/$desired replicas ready"
                } else {
                    Write-Log "⚠ Deployment $name: $ready/$desired replicas ready"
                }
            }
            
            return $true
        } else {
            Write-Log "⚠ No scaling resources found"
            return $true
        }
    }
    catch {
        Write-Log "✗ Pod scaling test failed: $($_.Exception.Message)"
        return $false
    }
}

# Get pod metrics
function Get-PodMetrics {
    Write-Log "Collecting pod metrics..."
    
    try {
        $selector = if ($LabelSelector) { "-l $LabelSelector" } else { "" }
        $pods = Get-KubePod -Namespace $Namespace $selector
        
        $metrics = @()
        
        # Basic pod metrics
        $metrics += @{
            Name = "TotalPods"
            Value = $pods.Count
            Unit = "Count"
        }
        
        $runningPods = ($pods | Where-Object { $_.Status.Phase -eq "Running" }).Count
        $metrics += @{
            Name = "RunningPods"
            Value = $runningPods
            Unit = "Count"
        }
        
        # Resource metrics (if available)
        try {
            $topOutput = kubectl top pod -n $Namespace $selector --no-headers 2>$null
            if ($topOutput) {
                $totalCPU = 0
                $totalMemory = 0
                
                foreach ($line in $topOutput -split '\n') {
                    $parts = $line -split '\s+'
                    $cpu = $parts[1] -replace 'm', ''
                    $memory = $parts[2] -replace 'Mi', ''
                    
                    $totalCPU += [int]$cpu
                    $totalMemory += [int]$memory
                }
                
                $metrics += @{
                    Name = "TotalCPU"
                    Value = $totalCPU
                    Unit = "millicores"
                }
                
                $metrics += @{
                    Name = "TotalMemory"
                    Value = $totalMemory
                    Unit = "MB"
                }
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve resource metrics"
        }
        
        return $metrics
    }
    catch {
        Write-Log "✗ Failed to collect metrics: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
Write-Log "Starting Kubernetes pod chaos validation..."
Write-Log "Namespace: $Namespace"
Write-Log "Label Selector: $LabelSelector"

# Connect to cluster
if (-not (Connect-KubernetesCluster)) {
    exit 1
}

$testResults = @()

# Run all tests
$testResults += @{ Test = "PodHealth"; Result = (Test-PodHealth) }
$testResults += @{ Test = "PodRestarts"; Result = (Test-PodRestarts) }
$testResults += @{ Test = "PodResources"; Result = (Test-PodResources) }
$testResults += @{ Test = "PodNetwork"; Result = (Test-PodNetwork) }
$testResults += @{ Test = "PodProbes"; Result = (Test-PodProbes) }
$testResults += @{ Test = "PodScaling"; Result = (Test-PodScaling) }

# Get metrics
$metrics = Get-PodMetrics

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
    Write-Log "All tests passed - Pods healthy"
    exit 0
} else {
    Write-Log "Some tests failed - Pod issues detected"
    exit 1
}
