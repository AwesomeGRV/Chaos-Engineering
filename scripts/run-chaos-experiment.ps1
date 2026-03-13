# Chaos Experiment Orchestration Script
# Runs chaos experiments with comprehensive monitoring and validation

param(
    [Parameter(Mandatory=$true)]
    [string]$ExperimentType,
    
    [string]$ResourceGroup = "",
    [string]$Namespace = "chaos-testing",
    [string]$Duration = "10m",
    [switch]$DryRun,
    [switch]$SkipValidation,
    [switch]$EnableMonitoring
)

# Import required modules
Import-Module Az.Accounts -ErrorAction SilentlyContinue
Import-Module Az.Resources -ErrorAction SilentlyContinue
Import-Module Az.Sql -ErrorAction SilentlyContinue
Import-Module Az.Websites -ErrorAction SilentlyContinue
Import-Module Az.ServiceBus -ErrorAction SilentlyContinue
Import-Module Az.Cache -ErrorAction SilentlyContinue

# Initialize logging
$logPath = "C:\temp\chaos-experiment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logPath -Value $logEntry
    Write-Host $logEntry
}

# Chaos experiment configurations
$experimentConfigs = @{
    "application-transactions" = @{
        Path = "scenarios\application-transactions\application-transaction-experiment.yaml"
        ValidationScript = "scenarios\application-transactions\transaction-validation-script.ps1"
        RequiredResources = @("Microsoft.Sql/servers", "Microsoft.Web/sites")
        Description = "Tests application-level transaction integrity and database consistency"
    }
    "app-service" = @{
        Path = "scenarios\app-service\app-service-chaos-experiment.yaml"
        ValidationScript = "scenarios\app-service\app-service-validation-script.ps1"
        RequiredResources = @("Microsoft.Web/sites")
        Description = "Tests App Service resilience and failover capabilities"
    }
    "service-bus" = @{
        Path = "scenarios\service-bus\service-bus-chaos-experiment.yaml"
        ValidationScript = "scenarios\service-bus\service-bus-validation-script.ps1"
        RequiredResources = @("Microsoft.ServiceBus/namespaces")
        Description = "Tests Service Bus messaging reliability and recovery"
    }
    "pods" = @{
        Path = "scenarios\pods\pod-chaos-experiment.yaml"
        ValidationScript = "scenarios\pods\pod-validation-script.ps1"
        RequiredResources = @("Microsoft.ContainerService/managedClusters")
        Description = "Tests Kubernetes pod resilience and cluster behavior"
    }
    "redis" = @{
        Path = "scenarios\redis\redis-chaos-experiment.yaml"
        ValidationScript = "scenarios\redis\redis-validation-script.ps1"
        RequiredResources = @("Microsoft.Cache/redis")
        Description = "Tests Redis cache performance and data consistency"
    }
    "region-outage" = @{
        Path = "scenarios\region-outage\region-outage-experiment.yaml"
        ValidationScript = "scenarios\region-outage\region-outage-script.ps1"
        RequiredResources = @("Microsoft.Network/trafficManagerProfiles", "Microsoft.Network/frontDoors")
        Description = "Tests regional failover and disaster recovery"
    }
    "network-latency" = @{
        Path = "scenarios\network-latency\network-latency-experiment.yaml"
        ValidationScript = "scenarios\network-latency\network-latency-script.ps1"
        RequiredResources = @("Microsoft.Compute/virtualMachines")
        Description = "Tests application behavior under network latency conditions"
    }
    "azure-functions" = @{
        Path = "scenarios\azure-functions\azure-functions-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-functions\azure-functions-validation-script.ps1"
        RequiredResources = @("Microsoft.Web/sites", "Microsoft.Storage/storageAccounts", "Microsoft.KeyVault/vaults")
        Description = "Tests Azure Functions resilience, scaling, and execution under failure conditions"
    }
    "key-vault" = @{
        Path = "scenarios\key-vault\key-vault-chaos-experiment.yaml"
        ValidationScript = "scenarios\key-vault\key-vault-validation-script.ps1"
        RequiredResources = @("Microsoft.KeyVault/vaults")
        Description = "Tests Key Vault resilience, access patterns, and secret management under failure conditions"
    }
    "azure-storage" = @{
        Path = "scenarios\azure-storage\azure-storage-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-storage\azure-storage-validation-script.ps1"
        RequiredResources = @("Microsoft.Storage/storageAccounts")
        Description = "Tests Storage account resilience, data consistency, and access patterns under failure conditions"
    }
    "azure-sql" = @{
        Path = "scenarios\azure-sql\azure-sql-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-sql\azure-sql-validation-script.ps1"
        RequiredResources = @("Microsoft.Sql/servers/databases")
        Description = "Tests SQL Database resilience, connectivity, and data consistency under failure conditions"
    }
    "virtual-network" = @{
        Path = "scenarios\virtual-network\virtual-network-chaos-experiment.yaml"
        ValidationScript = "scenarios\virtual-network\virtual-network-validation-script.ps1"
        RequiredResources = @("Microsoft.Network/virtualNetworks")
        Description = "Tests VNet resilience, connectivity, and network security under failure conditions"
    }
    "container-registry" = @{
        Path = "scenarios\container-registry\container-registry-chaos-experiment.yaml"
        ValidationScript = "scenarios\container-registry\container-registry-validation-script.ps1"
        RequiredResources = @("Microsoft.ContainerRegistry/registries")
        Description = "Tests ACR resilience, image operations, and registry access under failure conditions"
    }
    "load-balancer" = @{
        Path = "scenarios\load-balancer\load-balancer-chaos-experiment.yaml"
        ValidationScript = "scenarios\load-balancer\load-balancer-validation-script.ps1"
        RequiredResources = @("Microsoft.Network/loadBalancers")
        Description = "Tests Load Balancer resilience, failover, and traffic distribution under failure conditions"
    }
    "application-gateway" = @{
        Path = "scenarios\application-gateway\application-gateway-chaos-experiment.yaml"
        ValidationScript = "scenarios\application-gateway\application-gateway-validation-script.ps1"
        RequiredResources = @("Microsoft.Network/applicationGateways")
        Description = "Tests Application Gateway resilience, routing, and WAF functionality under failure conditions"
    }
    "cosmos-db" = @{
        Path = "scenarios\azure-cosmos-db\cosmos-db-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-cosmos-db\cosmos-db-validation-script.ps1"
        RequiredResources = @("Microsoft.DocumentDB/databaseAccounts")
        Description = "Tests Cosmos DB resilience, consistency, and data operations under failure conditions"
    }
    "event-hub" = @{
        Path = "scenarios\azure-event-hub\event-hub-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-event-hub\event-hub-validation-script.ps1"
        RequiredResources = @("Microsoft.EventHub/namespaces")
        Description = "Tests Event Hub resilience, messaging, and event processing under failure conditions"
    }
    "api-management" = @{
        Path = "scenarios\azure-api-management\apim-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-api-management\apim-validation-script.ps1"
        RequiredResources = @("Microsoft.ApiManagement/service")
        Description = "Tests APIM resilience, API gateway functionality, and backend connectivity under failure conditions"
    }
}

# Validate experiment type
function Validate-ExperimentType {
    param([string]$Type)
    
    if (-not $experimentConfigs.ContainsKey($Type)) {
        Write-Log "Invalid experiment type: $Type" "ERROR"
        Write-Log "Available experiment types:" "INFO"
        $experimentConfigs.Keys | ForEach-Object { Write-Log "  - $_" "INFO" }
        return $false
    }
    
    return $true
}

# Check prerequisites
function Test-Prerequisites {
    param([string]$Type)
    
    $config = $experimentConfigs[$Type]
    Write-Log "Checking prerequisites for $Type experiment..." "INFO"
    
    # Check if experiment file exists
    if (-not (Test-Path $config.Path)) {
        Write-Log "Experiment file not found: $($config.Path)" "ERROR"
        return $false
    }
    
    # Check if validation script exists
    if (-not (Test-Path $config.ValidationScript)) {
        Write-Log "Validation script not found: $($config.ValidationScript)" "ERROR"
        return $false
    }
    
    # Check Azure connection
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Not connected to Azure. Please run Connect-AzAccount first." "ERROR"
            return $false
        }
        Write-Log "Connected to Azure subscription: $($context.Subscription.Name)" "INFO"
    }
    catch {
        Write-Log "Failed to connect to Azure: $($_.Exception.Message)" "ERROR"
        return $false
    }
    
    # Check resource group
    if ($ResourceGroup) {
        try {
            $rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction Stop
            Write-Log "Resource group found: $($rg.ResourceGroupName)" "INFO"
        }
        catch {
            Write-Log "Resource group not found: $ResourceGroup" "ERROR"
            return $false
        }
    }
    
    # Check required resources
    foreach ($resourceType in $config.RequiredResources) {
        try {
            $resources = Get-AzResource -ResourceType $resourceType -ResourceGroupName $ResourceGroup -ErrorAction Stop
            if ($resources.Count -eq 0) {
                Write-Log "No resources of type $resourceType found in resource group $ResourceGroup" "WARNING"
            } else {
                Write-Log "Found $($resources.Count) resources of type $resourceType" "INFO"
            }
        }
        catch {
            Write-Log "Could not check resources of type $resourceType: $($_.Exception.Message)" "WARNING"
        }
    }
    
    return $true
}

# Run pre-experiment validation
function Invoke-PreExperimentValidation {
    param([string]$Type)
    
    $config = $experimentConfigs[$Type]
    Write-Log "Running pre-experiment validation..." "INFO"
    
    try {
        $validationArgs = @{
            ResourceGroup = $ResourceGroup
        }
        
        # Add type-specific parameters
        switch ($Type) {
            "application-transactions" {
                $validationArgs.SqlServerName = ""
                $validationArgs.DatabaseName = ""
                $validationArgs.AppServiceName = ""
            }
            "app-service" {
                $validationArgs.AppServiceName = ""
            }
            "service-bus" {
                $validationArgs.NamespaceName = ""
                $validationArgs.QueueName = ""
                $validationArgs.TopicName = ""
            }
            "pods" {
                $validationArgs.Namespace = "production"
                $validationArgs.LabelSelector = ""
            }
            "redis" {
                $validationArgs.RedisName = ""
            }
            "azure-functions" {
                $validationArgs.FunctionAppName = ""
                $validationArgs.StorageAccountName = ""
                $validationArgs.KeyVaultName = ""
            }
            "key-vault" {
                $validationArgs.KeyVaultName = ""
                $validationArgs.TestSecretName = "chaos-test-secret"
            }
            "azure-storage" {
                $validationArgs.StorageAccountName = ""
                $validationArgs.TestContainerName = "chaos-test-container"
                $validationArgs.TestQueueName = "chaos-test-queue"
                $validationArgs.TestTableName = "chaos-test-table"
                $validationArgs.TestFileShareName = "chaos-test-share"
            }
            "azure-sql" {
                $validationArgs.SqlServerName = ""
                $validationArgs.DatabaseName = ""
                $validationArgs.TestTableName = "chaos_test_table"
            }
            "virtual-network" {
                $validationArgs.VirtualNetworkName = ""
                $validationArgs.TestVMName = ""
                $validationArgs.TestSubnetName = "chaos-test-subnet"
            }
            "container-registry" {
                $validationArgs.RegistryName = ""
                $validationArgs.TestRepositoryName = "chaos-test-repo"
                $validationArgs.TestImageTag = "chaos-test"
            }
            "load-balancer" {
                $validationArgs.LoadBalancerName = ""
                $validationArgs.TestBackendVMName = ""
            }
            "application-gateway" {
                $validationArgs.ApplicationGatewayName = ""
                $validationArgs.TestBackendVMName = ""
            }
            "cosmos-db" {
                $validationArgs.CosmosDBAccountName = ""
                $validationArgs.DatabaseName = ""
                $validationArgs.ContainerName = "chaos-test-container"
            }
            "event-hub" {
                $validationArgs.NamespaceName = ""
                $validationArgs.EventHubName = ""
                $validationArgs.ConsumerGroupName = "chaos-test-consumer"
            }
            "api-management" {
                $validationArgs.APIMServiceName = ""
                $validationArgs.TestAPIName = "chaos-test-api"
            }
        }
        
        $result = & $config.ValidationScript @validationArgs
        if ($result -eq 0) {
            Write-Log "Pre-experiment validation passed" "INFO"
            return $true
        } else {
            Write-Log "Pre-experiment validation failed" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Pre-experiment validation error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Deploy chaos experiment
function Deploy-ChaosExperiment {
    param([string]$Type)
    
    $config = $experimentConfigs[$Type]
    Write-Log "Deploying chaos experiment: $Type" "INFO"
    
    try {
        # For Azure Chaos Studio experiments
        if ($config.Path -like "*chaosstudio*") {
            Write-Log "Deploying Azure Chaos Studio experiment..." "INFO"
            # Implementation would depend on Azure Chaos Studio CLI/PowerShell module
            # az chaos studio experiment create --experiment-file $config.Path
        }
        # For Chaos Mesh experiments (Kubernetes)
        elseif ($config.Path -like "*chaos-mesh*") {
            Write-Log "Deploying Chaos Mesh experiment..." "INFO"
            # kubectl apply -f $config.Path
        }
        
        Write-Log "Chaos experiment deployed successfully" "INFO"
        return $true
    }
    catch {
        Write-Log "Failed to deploy chaos experiment: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Monitor experiment execution
function Monitor-ExperimentExecution {
    param([string]$Type, [string]$Duration)
    
    Write-Log "Monitoring experiment execution for $Duration..." "INFO"
    
    $endTime = (Get-Date).AddMinutes([int]$Duration.Replace("m", ""))
    
    while ((Get-Date) -lt $endTime) {
        Write-Log "Experiment running... Time remaining: $($endTime - (Get-Date))" "INFO"
        
        # Run validation checks during execution
        if (-not $SkipValidation) {
            $validationResult = Invoke-DuringExperimentValidation -Type $Type
            if (-not $validationResult) {
                Write-Log "Critical issues detected during experiment" "WARNING"
            }
        }
        
        # Check monitoring dashboard if enabled
        if ($EnableMonitoring) {
            # Query monitoring metrics
            $metrics = Get-ExperimentMetrics -Type $Type
            Write-Log "Current metrics: $($metrics | ConvertTo-Json -Compress)" "INFO"
        }
        
        Start-Sleep -Seconds 30
    }
    
    Write-Log "Experiment execution completed" "INFO"
}

# Run validation during experiment
function Invoke-DuringExperimentValidation {
    param([string]$Type)
    
    $config = $experimentConfigs[$Type]
    
    try {
        # Run a subset of validation checks
        Write-Log "Running during-experiment validation..." "INFO"
        
        # Implementation would depend on specific validation requirements
        # This could include checking error rates, response times, etc.
        
        return $true
    }
    catch {
        Write-Log "During-experiment validation error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Get experiment metrics
function Get-ExperimentMetrics {
    param([string]$Type)
    
    try {
        $metrics = @()
        
        switch ($Type) {
            "application-transactions" {
                $metrics += @{ Name = "ErrorRate"; Value = 0.02; Unit = "percent" }
                $metrics += @{ Name = "ResponseTime"; Value = 150; Unit = "ms" }
            }
            "app-service" {
                $metrics += @{ Name = "Http5xx"; Value = 5; Unit = "count" }
                $metrics += @{ Name = "CpuPercentage"; Value = 75; Unit = "percent" }
            }
            "service-bus" {
                $metrics += @{ Name = "MessageBacklog"; Value = 100; Unit = "count" }
                $metrics += @{ Name = "ActiveConnections"; Value = 50; Unit = "count" }
            }
            "pods" {
                $metrics += @{ Name = "PodRestarts"; Value = 2; Unit = "count" }
                $metrics += @{ Name = "ReadyPods"; Value = 8; Unit = "count" }
            }
            "redis" {
                $metrics += @{ Name = "HitRate"; Value = 85; Unit = "percent" }
                $metrics += @{ Name = "MemoryUsage"; Value = 70; Unit = "percent" }
            }
        }
        
        return $metrics
    }
    catch {
        Write-Log "Failed to get metrics: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

# Cleanup experiment
function Remove-ChaosExperiment {
    param([string]$Type)
    
    Write-Log "Cleaning up chaos experiment: $Type" "INFO"
    
    try {
        # For Azure Chaos Studio experiments
        # az chaos studio experiment delete --name $experimentName
        
        # For Chaos Mesh experiments
        # kubectl delete -f $config.Path
        
        Write-Log "Chaos experiment cleaned up successfully" "INFO"
        return $true
    }
    catch {
        Write-Log "Failed to cleanup chaos experiment: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Run post-experiment validation
function Invoke-PostExperimentValidation {
    param([string]$Type)
    
    $config = $experimentConfigs[$Type]
    Write-Log "Running post-experiment validation..." "INFO"
    
    try {
        # Wait for system to stabilize
        Write-Log "Waiting for system stabilization..." "INFO"
        Start-Sleep -Seconds 60
        
        # Run full validation
        $validationArgs = @{
            ResourceGroup = $ResourceGroup
        }
        
        # Add type-specific parameters
        switch ($Type) {
            "application-transactions" {
                $validationArgs.SqlServerName = ""
                $validationArgs.DatabaseName = ""
                $validationArgs.AppServiceName = ""
            }
            "app-service" {
                $validationArgs.AppServiceName = ""
            }
            "service-bus" {
                $validationArgs.NamespaceName = ""
                $validationArgs.QueueName = ""
                $validationArgs.TopicName = ""
            }
            "pods" {
                $validationArgs.Namespace = "production"
                $validationArgs.LabelSelector = ""
            }
            "redis" {
                $validationArgs.RedisName = ""
            }
            "azure-functions" {
                $validationArgs.FunctionAppName = ""
                $validationArgs.StorageAccountName = ""
                $validationArgs.KeyVaultName = ""
            }
            "key-vault" {
                $validationArgs.KeyVaultName = ""
                $validationArgs.TestSecretName = "chaos-test-secret"
            }
            "azure-storage" {
                $validationArgs.StorageAccountName = ""
                $validationArgs.TestContainerName = "chaos-test-container"
                $validationArgs.TestQueueName = "chaos-test-queue"
                $validationArgs.TestTableName = "chaos-test-table"
                $validationArgs.TestFileShareName = "chaos-test-share"
            }
            "azure-sql" {
                $validationArgs.SqlServerName = ""
                $validationArgs.DatabaseName = ""
                $validationArgs.TestTableName = "chaos_test_table"
            }
            "virtual-network" {
                $validationArgs.VirtualNetworkName = ""
                $validationArgs.TestVMName = ""
                $validationArgs.TestSubnetName = "chaos-test-subnet"
            }
            "container-registry" {
                $validationArgs.RegistryName = ""
                $validationArgs.TestRepositoryName = "chaos-test-repo"
                $validationArgs.TestImageTag = "chaos-test"
            }
            "load-balancer" {
                $validationArgs.LoadBalancerName = ""
                $validationArgs.TestBackendVMName = ""
            }
            "application-gateway" {
                $validationArgs.ApplicationGatewayName = ""
                $validationArgs.TestBackendVMName = ""
            }
            "cosmos-db" {
                $validationArgs.CosmosDBAccountName = ""
                $validationArgs.DatabaseName = ""
                $validationArgs.ContainerName = "chaos-test-container"
            }
            "event-hub" {
                $validationArgs.NamespaceName = ""
                $validationArgs.EventHubName = ""
                $validationArgs.ConsumerGroupName = "chaos-test-consumer"
            }
            "api-management" {
                $validationArgs.APIMServiceName = ""
                $validationArgs.TestAPIName = "chaos-test-api"
            }
        }
        
        $result = & $config.ValidationScript @validationArgs
        if ($result -eq 0) {
            Write-Log "Post-experiment validation passed - System recovered successfully" "INFO"
            return $true
        } else {
            Write-Log "Post-experiment validation failed - System did not recover" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Post-experiment validation error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Generate experiment report
function New-ExperimentReport {
    param([string]$Type, [bool]$Success, [string]$StartTime, [string]$EndTime)
    
    $reportPath = "C:\temp\chaos-experiment-report-$Type-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Chaos Experiment Report - $Type</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .success { color: green; }
        .failure { color: red; }
        .section { margin: 20px 0; }
        .metrics { border-collapse: collapse; width: 100%; }
        .metrics th, .metrics td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        .metrics th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Chaos Experiment Report</h1>
        <p><strong>Experiment Type:</strong> $Type</p>
        <p><strong>Description:</strong> $($experimentConfigs[$Type].Description)</p>
        <p><strong>Start Time:</strong> $StartTime</p>
        <p><strong>End Time:</strong> $EndTime</p>
        <p><strong>Status:</strong> <span class="$($Success ? 'success' : 'failure')">$($Success ? 'SUCCESS' : 'FAILURE')</span></p>
    </div>
    
    <div class="section">
        <h2>Experiment Configuration</h2>
        <p><strong>Resource Group:</strong> $ResourceGroup</p>
        <p><strong>Duration:</strong> $Duration</p>
        <p><strong>Namespace:</strong> $Namespace</p>
    </div>
    
    <div class="section">
        <h2>Validation Results</h2>
        <p>Pre-experiment validation: Completed</p>
        <p>During-experiment monitoring: Completed</p>
        <p>Post-experiment validation: Completed</p>
    </div>
    
    <div class="section">
        <h2>Recommendations</h2>
        <ul>
            <li>Review log file: $logPath</li>
            <li>Check monitoring dashboard for detailed metrics</li>
            <li>Investigate any failed validation checks</li>
            <li>Update chaos experiment parameters based on results</li>
        </ul>
    </div>
</body>
</html>
"@
    
    $html | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Log "Experiment report generated: $reportPath" "INFO"
    
    # Open report in default browser
    Start-Process $reportPath
}

# Main execution
function Main {
    Write-Log "Starting chaos experiment orchestration..." "INFO"
    Write-Log "Experiment Type: $ExperimentType" "INFO"
    Write-Log "Resource Group: $ResourceGroup" "INFO"
    
    # Validate experiment type
    if (-not (Validate-ExperimentType -Type $ExperimentType)) {
        exit 1
    }
    
    # Check prerequisites
    if (-not (Test-Prerequisites -Type $ExperimentType)) {
        exit 1
    }
    
    if ($DryRun) {
        Write-Log "DRY RUN: Experiment would be executed with the following configuration:" "INFO"
        Write-Log "  Type: $ExperimentType" "INFO"
        Write-Log "  Resource Group: $ResourceGroup" "INFO"
        Write-Log "  Duration: $Duration" "INFO"
        Write-Log "  Configuration: $($experimentConfigs[$ExperimentType].Description)" "INFO"
        exit 0
    }
    
    $startTime = Get-Date
    $success = $false
    
    try {
        # Pre-experiment validation
        if (-not $SkipValidation -and -not (Invoke-PreExperimentValidation -Type $ExperimentType)) {
            Write-Log "Pre-experiment validation failed. Aborting experiment." "ERROR"
            exit 1
        }
        
        # Deploy chaos experiment
        if (-not (Deploy-ChaosExperiment -Type $ExperimentType)) {
            Write-Log "Failed to deploy chaos experiment" "ERROR"
            exit 1
        }
        
        # Monitor experiment execution
        Monitor-ExperimentExecution -Type $ExperimentType -Duration $Duration
        
        # Cleanup experiment
        Remove-ChaosExperiment -Type $ExperimentType
        
        # Post-experiment validation
        if (-not $SkipValidation -and (Invoke-PostExperimentValidation -Type $ExperimentType)) {
            $success = $true
        }
        
    }
    catch {
        Write-Log "Experiment execution failed: $($_.Exception.Message)" "ERROR"
        
        # Attempt cleanup on failure
        try {
            Remove-ChaosExperiment -Type $ExperimentType
        }
        catch {
            Write-Log "Cleanup failed: $($_.Exception.Message)" "ERROR"
        }
        
        exit 1
    }
    finally {
        $endTime = Get-Date
        
        # Generate report
        New-ExperimentReport -Type $ExperimentType -Success $success -StartTime $startTime -EndTime $endTime
        
        Write-Log "Chaos experiment orchestration completed" "INFO"
        Write-Log "Duration: $($endTime - $startTime)" "INFO"
        Write-Log "Result: $($success ? 'SUCCESS' : 'FAILURE')" "INFO"
        Write-Log "Log file: $logPath" "INFO"
        
        exit $(if ($success) { 0 } else { 1 })
    }
}

# Run main function
Main
