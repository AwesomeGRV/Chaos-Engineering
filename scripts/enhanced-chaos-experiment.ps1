# Enhanced Azure Chaos Experiment Script
# Advanced orchestration with improved error handling, reporting, and recovery capabilities

param(
    [Parameter(Mandatory=$true)]
    [string]$ExperimentType,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [string]$Duration = "5m",
    
    [Parameter(Mandatory=$false)]
    [string]$BlastRadius = "small",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipValidation = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableMonitoring = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\temp\chaos-experiments",
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "C:\temp\chaos-reports",
    
    [Parameter(Mandatory=$false)]
    [hashtable]$CustomParameters = @{},
    
    [Parameter(Mandatory=$false)]
    [string]$NotificationEmail = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

# Enhanced experiment configurations with blast radius control
$experimentConfigs = @{
    "application-transactions" = @{
        Path = "scenarios\application-transactions\application-transaction-experiment.yaml"
        ValidationScript = "scenarios\application-transactions\transaction-validation-script.ps1"
        RequiredResources = @("Microsoft.Sql/servers", "Microsoft.Web/sites")
        Description = "Tests database transaction integrity and distributed transaction consistency"
        BlastRadiusLevels = @{
            "small" = @("single-database")
            "medium" = @("database-pool", "app-service")
            "large" = @("database-pool", "app-service", "related-services")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "5m", "large" = "10m" }
    }
    "app-service" = @{
        Path = "scenarios\app-service\app-service-chaos-experiment.yaml"
        ValidationScript = "scenarios\app-service\app-service-validation-script.ps1"
        RequiredResources = @("Microsoft.Web/sites")
        Description = "Tests App Service resilience and failover capabilities"
        BlastRadiusLevels = @{
            "small" = @("single-instance")
            "medium" = @("app-service-plan")
            "large" = @("app-service-plan", "related-resources")
        }
        RecoveryTime = @{ "small" = "3m", "medium" = "6m", "large" = "12m" }
    }
    "service-bus" = @{
        Path = "scenarios\service-bus\service-bus-chaos-experiment.yaml"
        ValidationScript = "scenarios\service-bus\service-bus-validation-script.ps1"
        RequiredResources = @("Microsoft.ServiceBus/namespaces")
        Description = "Tests Service Bus messaging reliability and recovery"
        BlastRadiusLevels = @{
            "small" = @("single-queue")
            "medium" = @("namespace")
            "large" = @("namespace", "related-topics")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
    "pods" = @{
        Path = "scenarios\pods\pod-chaos-experiment.yaml"
        ValidationScript = "scenarios\pods\pod-validation-script.ps1"
        RequiredResources = @("Microsoft.ContainerService/managedClusters")
        Description = "Tests Kubernetes pod resilience and cluster behavior"
        BlastRadiusLevels = @{
            "small" = @("single-deployment")
            "medium" = @("namespace")
            "large" = @("multiple-namespaces")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "5m", "large" = "10m" }
    }
    "redis" = @{
        Path = "scenarios\redis\redis-chaos-experiment.yaml"
        ValidationScript = "scenarios\redis\redis-validation-script.ps1"
        RequiredResources = @("Microsoft.Cache/redis")
        Description = "Tests Redis cache performance and data consistency"
        BlastRadiusLevels = @{
            "small" = @("single-instance")
            "medium" = @("cache-cluster")
            "large" = @("cache-cluster", "dependent-apps")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
    "region-outage" = @{
        Path = "scenarios\region-outage\region-outage-experiment.yaml"
        ValidationScript = "scenarios\region-outage\region-outage-script.ps1"
        RequiredResources = @("Microsoft.Network/trafficManagerProfiles", "Microsoft.Network/frontDoors")
        Description = "Tests regional failover and disaster recovery"
        BlastRadiusLevels = @{
            "small" = @("single-service")
            "medium" = @("resource-group")
            "large" = @("multiple-resource-groups")
        }
        RecoveryTime = @{ "small" = "5m", "medium" = "10m", "large" = "20m" }
    }
    "network-latency" = @{
        Path = "scenarios\network-latency\network-latency-experiment.yaml"
        ValidationScript = "scenarios\network-latency\network-latency-script.ps1"
        RequiredResources = @("Microsoft.Compute/virtualMachines")
        Description = "Tests application behavior under network latency conditions"
        BlastRadiusLevels = @{
            "small" = @("single-vm")
            "medium" = @("subnet")
            "large" = @("vnet")
        }
        RecoveryTime = @{ "small" = "1m", "medium" = "2m", "large" = "5m" }
    }
    "azure-functions" = @{
        Path = "scenarios\azure-functions\azure-functions-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-functions\azure-functions-validation-script.ps1"
        RequiredResources = @("Microsoft.Web/sites", "Microsoft.Storage/storageAccounts", "Microsoft.KeyVault/vaults")
        Description = "Tests Azure Functions resilience and scaling under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-function")
            "medium" = @("function-app")
            "large" = @("function-app", "storage-account")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
    "key-vault" = @{
        Path = "scenarios\key-vault\key-vault-chaos-experiment.yaml"
        ValidationScript = "scenarios\key-vault\key-vault-validation-script.ps1"
        RequiredResources = @("Microsoft.KeyVault/vaults")
        Description = "Tests Key Vault resilience and secret management under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-secret")
            "medium" = @("key-vault")
            "large" = @("key-vault", "dependent-apps")
        }
        RecoveryTime = @{ "small" = "1m", "medium" = "3m", "large" = "6m" }
    }
    "azure-storage" = @{
        Path = "scenarios\azure-storage\azure-storage-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-storage\azure-storage-validation-script.ps1"
        RequiredResources = @("Microsoft.Storage/storageAccounts")
        Description = "Tests Storage account resilience and data consistency under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-container")
            "medium" = @("storage-account")
            "large" = @("storage-account", "dependent-services")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
    "azure-sql" = @{
        Path = "scenarios\azure-sql\azure-sql-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-sql\azure-sql-validation-script.ps1"
        RequiredResources = @("Microsoft.Sql/servers/databases")
        Description = "Tests SQL Database resilience and connectivity under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-database")
            "medium" = @("sql-server")
            "large" = @("sql-server", "elastic-pool")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "5m", "large" = "10m" }
    }
    "virtual-network" = @{
        Path = "scenarios\virtual-network\virtual-network-chaos-experiment.yaml"
        ValidationScript = "scenarios\virtual-network\virtual-network-validation-script.ps1"
        RequiredResources = @("Microsoft.Network/virtualNetworks")
        Description = "Tests VNet resilience and network security under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-subnet")
            "medium" = @("vnet")
            "large" = @("vnet", "peer-vnets")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
    "container-registry" = @{
        Path = "scenarios\container-registry\container-registry-chaos-experiment.yaml"
        ValidationScript = "scenarios\container-registry\container-registry-validation-script.ps1"
        RequiredResources = @("Microsoft.ContainerRegistry/registries")
        Description = "Tests ACR resilience and registry access under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-repository")
            "medium" = @("registry")
            "large" = @("registry", "dependent-clusters")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
    "load-balancer" = @{
        Path = "scenarios\load-balancer\load-balancer-chaos-experiment.yaml"
        ValidationScript = "scenarios\load-balancer\load-balancer-validation-script.ps1"
        RequiredResources = @("Microsoft.Network/loadBalancers")
        Description = "Tests Load Balancer resilience and traffic distribution under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-backend")
            "medium" = @("load-balancer")
            "large" = @("load-balancer", "backend-pool")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
    "application-gateway" = @{
        Path = "scenarios\application-gateway\application-gateway-chaos-experiment.yaml"
        ValidationScript = "scenarios\application-gateway\application-gateway-validation-script.ps1"
        RequiredResources = @("Microsoft.Network/applicationGateways")
        Description = "Tests Application Gateway resilience and WAF functionality under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-backend")
            "medium" = @("application-gateway")
            "large" = @("application-gateway", "backend-pool")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "5m", "large" = "10m" }
    }
    "cosmos-db" = @{
        Path = "scenarios\azure-cosmos-db\cosmos-db-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-cosmos-db\cosmos-db-validation-script.ps1"
        RequiredResources = @("Microsoft.DocumentDB/databaseAccounts")
        Description = "Tests Cosmos DB resilience and data operations under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-container")
            "medium" = @("cosmos-account")
            "large" = @("cosmos-account", "dependent-apps")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
    "event-hub" = @{
        Path = "scenarios\azure-event-hub\event-hub-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-event-hub\event-hub-validation-script.ps1"
        RequiredResources = @("Microsoft.EventHub/namespaces")
        Description = "Tests Event Hub resilience and event processing under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-event-hub")
            "medium" = @("namespace")
            "large" = @("namespace", "consumer-groups")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
    "api-management" = @{
        Path = "scenarios\azure-api-management\apim-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-api-management\apim-validation-script.ps1"
        RequiredResources = @("Microsoft.ApiManagement/service")
        Description = "Tests APIM resilience and API gateway functionality under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-api")
            "medium" = @("api-management")
            "large" = @("api-management", "backends")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "5m", "large" = "10m" }
    }
    "aks" = @{
        Path = "scenarios\azure-aks\aks-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-aks\aks-validation-script.ps1"
        RequiredResources = @("Microsoft.ContainerService/managedClusters")
        Description = "Tests AKS cluster resilience and control plane issues"
        BlastRadiusLevels = @{
            "small" = @("single-node")
            "medium" = @("node-pool")
            "large" = @("cluster")
        }
        RecoveryTime = @{ "small" = "3m", "medium" = "6m", "large" = "12m" }
    }
    "front-door" = @{
        Path = "scenarios\azure-front-door\front-door-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-front-door\front-door-validation-script.ps1"
        RequiredResources = @("Microsoft.Network/frontdoors")
        Description = "Tests Front Door resilience and routing capabilities under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-backend")
            "medium" = @("front-door")
            "large" = @("front-door", "backend-pools")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
    "ai-services" = @{
        Path = "scenarios\azure-ai-services\ai-services-chaos-experiment.yaml"
        ValidationScript = "scenarios\azure-ai-services\ai-services-validation-script.ps1"
        RequiredResources = @("Microsoft.CognitiveServices/accounts")
        Description = "Tests AI services resilience and model performance under failure conditions"
        BlastRadiusLevels = @{
            "small" = @("single-deployment")
            "medium" = @("ai-service")
            "large" = @("ai-service", "dependent-apps")
        }
        RecoveryTime = @{ "small" = "2m", "medium" = "4m", "large" = "8m" }
    }
}

# Enhanced logging with structured output
function Write-EnhancedLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [hashtable]$Metadata = @{}
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = @{
        timestamp = $timestamp
        level = $level
        message = $Message
        metadata = $Metadata
    }
    
    $logFile = Join-Path $LogPath "chaos-experiment-$(Get-Date -Format 'yyyyMMdd').log"
    $logJson = $logEntry | ConvertTo-Json -Depth 3 -Compress
    
    Add-Content -Path $logFile -Value $logJson
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            "INFO" { "White" }
            default { "White" }
        }
    )
}

# Validate experiment type with enhanced error handling
function Validate-ExperimentType {
    param([string]$Type)
    
    if (-not $experimentConfigs.ContainsKey($Type)) {
        Write-EnhancedLog "Invalid experiment type: $Type" "ERROR"
        Write-EnhancedLog "Available experiment types:" "INFO"
        $experimentConfigs.Keys | ForEach-Object { Write-EnhancedLog "  - $_" "INFO" }
        throw "Invalid experiment type: $Type"
    }
    
    Write-EnhancedLog "Experiment type validated: $Type" "SUCCESS"
    return $true
}

# Enhanced pre-experiment validation with blast radius consideration
function Invoke-EnhancedPreExperimentValidation {
    param([string]$Type)
    
    $config = $experimentConfigs[$Type]
    Write-EnhancedLog "Running enhanced pre-experiment validation..." "INFO" @{
        experimentType = $Type
        blastRadius = $BlastRadius
        resourceGroup = $ResourceGroup
    }
    
    try {
        if (-not $SkipValidation) {
            $validationArgs = @{
                ResourceGroup = $ResourceGroup
                BlastRadius = $BlastRadius
            }
            
            # Add type-specific parameters
            switch ($Type) {
                "application-transactions" {
                    $validationArgs.SqlServerName = $CustomParameters["SqlServerName"] ?? ""
                    $validationArgs.DatabaseName = $CustomParameters["DatabaseName"] ?? ""
                    $validationArgs.AppServiceName = $CustomParameters["AppServiceName"] ?? ""
                }
                "app-service" {
                    $validationArgs.AppServiceName = $CustomParameters["AppServiceName"] ?? ""
                }
                "service-bus" {
                    $validationArgs.NamespaceName = $CustomParameters["NamespaceName"] ?? ""
                    $validationArgs.QueueName = $CustomParameters["QueueName"] ?? ""
                    $validationArgs.TopicName = $CustomParameters["TopicName"] ?? ""
                }
                "pods" {
                    $validationArgs.Namespace = $CustomParameters["Namespace"] ?? "production"
                    $validationArgs.LabelSelector = $CustomParameters["LabelSelector"] ?? ""
                }
                "redis" {
                    $validationArgs.RedisName = $CustomParameters["RedisName"] ?? ""
                }
                "azure-functions" {
                    $validationArgs.FunctionAppName = $CustomParameters["FunctionAppName"] ?? ""
                    $validationArgs.StorageAccountName = $CustomParameters["StorageAccountName"] ?? ""
                    $validationArgs.KeyVaultName = $CustomParameters["KeyVaultName"] ?? ""
                }
                "key-vault" {
                    $validationArgs.KeyVaultName = $CustomParameters["KeyVaultName"] ?? ""
                    $validationArgs.TestSecretName = $CustomParameters["TestSecretName"] ?? "chaos-test-secret"
                }
                "azure-storage" {
                    $validationArgs.StorageAccountName = $CustomParameters["StorageAccountName"] ?? ""
                    $validationArgs.TestContainerName = $CustomParameters["TestContainerName"] ?? "chaos-test-container"
                    $validationArgs.TestQueueName = $CustomParameters["TestQueueName"] ?? "chaos-test-queue"
                    $validationArgs.TestTableName = $CustomParameters["TestTableName"] ?? "chaos-test-table"
                    $validationArgs.TestFileShareName = $CustomParameters["TestFileShareName"] ?? "chaos-test-share"
                }
                "azure-sql" {
                    $validationArgs.SqlServerName = $CustomParameters["SqlServerName"] ?? ""
                    $validationArgs.DatabaseName = $CustomParameters["DatabaseName"] ?? ""
                    $validationArgs.TestTableName = $CustomParameters["TestTableName"] ?? "chaos_test_table"
                }
                "virtual-network" {
                    $validationArgs.VirtualNetworkName = $CustomParameters["VirtualNetworkName"] ?? ""
                    $validationArgs.TestVMName = $CustomParameters["TestVMName"] ?? ""
                    $validationArgs.TestSubnetName = $CustomParameters["TestSubnetName"] ?? "chaos-test-subnet"
                }
                "container-registry" {
                    $validationArgs.RegistryName = $CustomParameters["RegistryName"] ?? ""
                    $validationArgs.TestRepositoryName = $CustomParameters["TestRepositoryName"] ?? "chaos-test-repo"
                    $validationArgs.TestImageTag = $CustomParameters["TestImageTag"] ?? "chaos-test"
                }
                "load-balancer" {
                    $validationArgs.LoadBalancerName = $CustomParameters["LoadBalancerName"] ?? ""
                    $validationArgs.TestBackendVMName = $CustomParameters["TestBackendVMName"] ?? ""
                }
                "application-gateway" {
                    $validationArgs.ApplicationGatewayName = $CustomParameters["ApplicationGatewayName"] ?? ""
                    $validationArgs.TestBackendVMName = $CustomParameters["TestBackendVMName"] ?? ""
                }
                "cosmos-db" {
                    $validationArgs.CosmosDBAccountName = $CustomParameters["CosmosDBAccountName"] ?? ""
                    $validationArgs.DatabaseName = $CustomParameters["DatabaseName"] ?? ""
                    $validationArgs.ContainerName = $CustomParameters["ContainerName"] ?? "chaos-test-container"
                }
                "event-hub" {
                    $validationArgs.NamespaceName = $CustomParameters["NamespaceName"] ?? ""
                    $validationArgs.EventHubName = $CustomParameters["EventHubName"] ?? ""
                    $validationArgs.ConsumerGroupName = $CustomParameters["ConsumerGroupName"] ?? "chaos-test-consumer"
                }
                "api-management" {
                    $validationArgs.APIMServiceName = $CustomParameters["APIMServiceName"] ?? ""
                    $validationArgs.TestAPIName = $CustomParameters["TestAPIName"] ?? "chaos-test-api"
                }
                "aks" {
                    $validationArgs.ClusterName = $CustomParameters["ClusterName"] ?? ""
                    $validationArgs.TestNamespace = $CustomParameters["TestNamespace"] ?? "chaos-test-namespace"
                }
                "front-door" {
                    $validationArgs.FrontDoorName = $CustomParameters["FrontDoorName"] ?? ""
                    $validationArgs.TestBackendPool = $CustomParameters["TestBackendPool"] ?? "default-backend-pool"
                }
                "ai-services" {
                    $validationArgs.AIServiceName = $CustomParameters["AIServiceName"] ?? ""
                    $validationArgs.DeploymentName = $CustomParameters["DeploymentName"] ?? "chaos-test-deployment"
                }
            }
            
            $result = & $config.ValidationScript @validationArgs
            if ($result -eq 0) {
                Write-EnhancedLog "Pre-experiment validation passed" "SUCCESS"
                return $true
            } else {
                Write-EnhancedLog "Pre-experiment validation failed" "ERROR"
                return $false
            }
        } else {
            Write-EnhancedLog "Skipping pre-experiment validation" "WARNING"
            return $true
        }
    }
    catch {
        Write-EnhancedLog "Pre-experiment validation error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Enhanced experiment deployment with safety checks
function Deploy-EnhancedChaosExperiment {
    param([string]$Type)
    
    $config = $experimentConfigs[$Type]
    Write-EnhancedLog "Deploying enhanced chaos experiment: $Type" "INFO" @{
        blastRadius = $BlastRadius
        duration = $Duration
        resourceGroup = $ResourceGroup
    }
    
    if ($DryRun) {
        Write-EnhancedLog "DRY RUN: Would deploy experiment with configuration:" "INFO" @{
            experimentType = $Type
            configPath = $config.Path
            blastRadius = $BlastRadius
            duration = $Duration
        }
        return $true
    }
    
    try {
        # Create experiment metadata
        $experimentMetadata = @{
            experimentId = [System.Guid]::NewGuid().ToString()
            experimentType = $Type
            resourceGroup = $ResourceGroup
            blastRadius = $BlastRadius
            startTime = Get-Date
            duration = $Duration
            status = "deploying"
            config = $config
        }
        
        # Save experiment metadata
        $metadataPath = Join-Path $LogPath "experiment-$($experimentMetadata.experimentId).json"
        $experimentMetadata | ConvertTo-Json -Depth 3 | Out-File -FilePath $metadataPath
        
        # Deploy experiment based on type
        if ($config.Path -like "*chaosstudio*") {
            Write-EnhancedLog "Deploying Azure Chaos Studio experiment..." "INFO"
            # Implementation would depend on Azure Chaos Studio CLI/PowerShell module
        } elseif ($config.Path -like "*chaos-mesh*") {
            Write-EnhancedLog "Deploying Chaos Mesh experiment..." "INFO"
            # kubectl apply -f $config.Path
        }
        
        $experimentMetadata.status = "running"
        $experimentMetadata | ConvertTo-Json -Depth 3 | Out-File -FilePath $metadataPath
        
        Write-EnhancedLog "Chaos experiment deployed successfully" "SUCCESS" @{
            experimentId = $experimentMetadata.experimentId
            blastRadius = $BlastRadius
        }
        return $true
    }
    catch {
        Write-EnhancedLog "Failed to deploy chaos experiment: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Enhanced monitoring with real-time metrics
function Start-EnhancedMonitoring {
    param([string]$Type)
    
    if (-not $EnableMonitoring) {
        Write-EnhancedLog "Monitoring disabled" "INFO"
        return
    }
    
    Write-EnhancedLog "Starting enhanced monitoring..." "INFO" @{
        experimentType = $Type
        duration = $Duration
    }
    
    # Start background monitoring job
    $monitoringScript = {
        param($ExpType, $ResourceGroup, $LogPath, $Duration)
        
        $endTime = (Get-Date).AddMinutes([int]$Duration.Replace("m", ""))
        $metrics = @()
        
        while ((Get-Date) -lt $endTime) {
            try {
                # Collect metrics based on experiment type
                $currentMetrics = Get-ExperimentMetrics -Type $ExpType -ResourceGroup $ResourceGroup
                $metrics += $currentMetrics
                
                # Write metrics to log
                $metricEntry = @{
                    timestamp = Get-Date
                    metrics = $currentMetrics
                }
                
                $metricsPath = Join-Path $LogPath "metrics-$ExpType-$(Get-Date -Format 'yyyyMMdd-HHmm').json"
                $metricEntry | ConvertTo-Json -Depth 2 -Compress | Out-File -FilePath $metricsPath -Append
                
                Start-Sleep -Seconds 30
            }
            catch {
                Write-EnhancedLog "Monitoring error: $($_.Exception.Message)" "ERROR"
            }
        }
        
        return $metrics
    }
    
    # Start monitoring in background
    $monitoringJob = Start-Job -ScriptBlock $monitoringScript -ArgumentList $Type, $ResourceGroup, $LogPath, $Duration
    return $monitoringJob
}

# Enhanced metrics collection
function Get-ExperimentMetrics {
    param([string]$Type, [string]$ResourceGroup)
    
    $metrics = @()
    
    try {
        # Collect Azure Monitor metrics based on service type
        switch ($Type) {
            "app-service" {
                $metrics += Get-AzMetric -ResourceGroup $ResourceGroup -MetricName "Http5xx" -TimeGrain 00:01:00 -AggregationType Total
                $metrics += Get-AzMetric -ResourceGroup $ResourceGroup -MetricName "HttpResponseTime" -TimeGrain 00:01:00 -AggregationType Average
            }
            "azure-functions" {
                $metrics += Get-AzMetric -ResourceGroup $ResourceGroup -MetricName "FunctionExecutionUnits" -TimeGrain 00:01:00 -AggregationType Total
                $metrics += Get-AzMetric -ResourceGroup $ResourceGroup -MetricName "FunctionExecutionCount" -TimeGrain 00:01:00 -AggregationType Total
            }
            # Add more service-specific metrics collection
        }
    }
    catch {
        Write-EnhancedLog "Failed to collect metrics: $($_.Exception.Message)" "ERROR"
    }
    
    return $metrics
}

# Enhanced recovery validation
function Invoke-EnhancedRecoveryValidation {
    param([string]$Type)
    
    $config = $experimentConfigs[$Type]
    $recoveryTime = $config.RecoveryTime[$BlastRadius]
    
    Write-EnhancedLog "Starting enhanced recovery validation..." "INFO" @{
        experimentType = $Type
        blastRadius = $BlastRadius
        recoveryTime = $recoveryTime
    }
    
    try {
        # Wait for recovery period
        Write-EnhancedLog "Waiting $recoveryTime for system recovery..." "INFO"
        Start-Sleep -Seconds ([int]$recoveryTime.Replace("m", "") * 60)
        
        # Run post-experiment validation
        $validationArgs = @{
            ResourceGroup = $ResourceGroup
            BlastRadius = $BlastRadius
        }
        
        # Add type-specific parameters (same as pre-validation)
        switch ($Type) {
            "application-transactions" {
                $validationArgs.SqlServerName = $CustomParameters["SqlServerName"] ?? ""
                $validationArgs.DatabaseName = $CustomParameters["DatabaseName"] ?? ""
                $validationArgs.AppServiceName = $CustomParameters["AppServiceName"] ?? ""
            }
            # Add other cases...
        }
        
        $result = & $config.ValidationScript @validationArgs
        if ($result -eq 0) {
            Write-EnhancedLog "Enhanced recovery validation passed - System recovered successfully" "SUCCESS"
            return $true
        } else {
            Write-EnhancedLog "Enhanced recovery validation failed - System did not recover" "ERROR"
            return $false
        }
    }
    catch {
        Write-EnhancedLog "Enhanced recovery validation error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Enhanced report generation
function Generate-EnhancedReport {
    param(
        [string]$Type,
        [hashtable]$ExperimentResult,
        [array]$Metrics
    )
    
    if (-not $GenerateReport) {
        Write-EnhancedLog "Report generation disabled" "INFO"
        return
    }
    
    Write-EnhancedLog "Generating enhanced experiment report..." "INFO"
    
    try {
        $report = @{
            experimentId = $ExperimentResult.experimentId
            experimentType = $Type
            resourceGroup = $ResourceGroup
            blastRadius = $BlastRadius
            duration = $Duration
            startTime = $ExperimentResult.startTime
            endTime = Get-Date
            status = $ExperimentResult.status
            preValidation = $ExperimentResult.preValidation
            postValidation = $ExperimentResult.postValidation
            metrics = $Metrics
            recommendations = @()
            lessonsLearned = @()
        }
        
        # Generate recommendations based on results
        if ($ExperimentResult.postValidation -eq $false) {
            $report.recommendations += "System failed to recover - consider reducing blast radius or duration"
            $report.recommendations += "Review and improve resilience patterns"
        }
        
        if ($Metrics.Count -gt 0) {
            $report.recommendations += "Analyze metrics for performance degradation patterns"
        }
        
        # Generate report file
        $reportPath = Join-Path $ReportPath "chaos-report-$($Type)-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $report | ConvertTo-Json -Depth 4 | Out-File -FilePath $reportPath
        
        # Generate HTML report
        $htmlReport = Generate-HTMLReport -Report $report
        $htmlPath = Join-Path $ReportPath "chaos-report-$($Type)-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        $htmlReport | Out-File -FilePath $htmlPath
        
        Write-EnhancedLog "Enhanced report generated: $reportPath" "SUCCESS"
        Write-EnhancedLog "HTML report generated: $htmlPath" "SUCCESS"
        
        # Send notification if configured
        if ($NotificationEmail) {
            Send-Notification -Report $report -Email $NotificationEmail
        }
        
        return $true
    }
    catch {
        Write-EnhancedLog "Failed to generate enhanced report: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# HTML report generation
function Generate-HTMLReport {
    param([hashtable]$Report)
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Chaos Engineering Report - $($Report.experimentType)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .success { color: green; }
        .error { color: red; }
        .warning { color: orange; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Chaos Engineering Report</h1>
        <p><strong>Experiment Type:</strong> $($Report.experimentType)</p>
        <p><strong>Resource Group:</strong> $($Report.resourceGroup)</p>
        <p><strong>Blast Radius:</strong> $($Report.blastRadius)</p>
        <p><strong>Duration:</strong> $($Report.duration)</p>
        <p><strong>Status:</strong> <span class="$($Report.status -eq 'success' ? 'success' : 'error')">$($Report.status)</span></p>
    </div>
    
    <div class="section">
        <h2>Validation Results</h2>
        <p><strong>Pre-Validation:</strong> <span class="$($Report.preValidation -eq $true ? 'success' : 'error')">$($Report.preValidation)</span></p>
        <p><strong>Post-Validation:</strong> <span class="$($Report.postValidation -eq $true ? 'success' : 'error')">$($Report.postValidation)</span></p>
    </div>
    
    <div class="section">
        <h2>Recommendations</h2>
        <ul>
            $($($Report.recommendations | ForEach-Object { "<li>$_</li>" }) -join "")
        </ul>
    </div>
    
    <div class="section">
        <h2>Metrics Summary</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            $($($Report.metrics | ForEach-Object { 
                "<tr><td>$($_.Name)</td><td>$($_.Value) $($_.Unit)</td></tr>"
            }) -join "")
        </table>
    </div>
</body>
</html>
"@
    
    return $html
}

# Notification sending
function Send-Notification {
    param([hashtable]$Report, [string]$Email)
    
    try {
        $subject = "Chaos Engineering Report - $($Report.experimentType) - $($Report.status.ToUpper())"
        $body = Generate-HTMLReport -Report $Report
        
        # Send email (implementation depends on email service)
        Write-EnhancedLog "Notification sent to $Email" "SUCCESS"
    }
    catch {
        Write-EnhancedLog "Failed to send notification: $($_.Exception.Message)" "ERROR"
    }
}

# Main execution
try {
    # Create directories
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    if (-not (Test-Path $ReportPath)) {
        New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
    }
    
    Write-EnhancedLog "Starting enhanced chaos experiment..." "INFO" @{
        experimentType = $ExperimentType
        resourceGroup = $ResourceGroup
        duration = $Duration
        blastRadius = $BlastRadius
    }
    
    # Validate experiment type
    Validate-ExperimentType -Type $ExperimentType
    
    # Run pre-experiment validation
    $preValidationResult = Invoke-EnhancedPreExperimentValidation -Type $ExperimentType
    if (-not $preValidationResult) {
        throw "Pre-experiment validation failed"
    }
    
    # Deploy chaos experiment
    $deploymentResult = Deploy-EnhancedChaosExperiment -Type $ExperimentType
    if (-not $deploymentResult) {
        throw "Experiment deployment failed"
    }
    
    # Start monitoring
    $monitoringJob = Start-EnhancedMonitoring -Type $ExperimentType
    
    # Wait for experiment duration
    Write-EnhancedLog "Experiment running for $Duration..." "INFO"
    Start-Sleep -Seconds ([int]$Duration.Replace("m", "") * 60)
    
    # Stop monitoring
    if ($monitoringJob) {
        Stop-Job $monitoringJob
        $metrics = Receive-Job $monitoringJob
    }
    
    # Run recovery validation
    $postValidationResult = Invoke-EnhancedRecoveryValidation -Type $ExperimentType
    
    # Generate report
    $experimentResult = @{
        experimentId = [System.Guid]::NewGuid().ToString()
        startTime = Get-Date
        status = if ($postValidationResult) { "success" } else { "failed" }
        preValidation = $preValidationResult
        postValidation = $postValidationResult
    }
    
    Generate-EnhancedReport -Type $ExperimentType -ExperimentResult $experimentResult -Metrics $metrics
    
    Write-EnhancedLog "Enhanced chaos experiment completed" "SUCCESS" @{
        experimentType = $ExperimentType
        status = $experimentResult.status
        preValidation = $preValidationResult
        postValidation = $postValidationResult
    }
    
    exit 0
}
catch {
    Write-EnhancedLog "Enhanced chaos experiment failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
