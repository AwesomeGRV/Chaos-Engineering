# Deployment Script for Chaos Engineering Infrastructure
# This script sets up the necessary Azure infrastructure for chaos experiments

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$false)]
    [string]$LogAnalyticsWorkspaceName = "chaos-logs",
    
    [Parameter(Mandatory=$false)]
    [string]$AppInsightsName = "chaos-insights",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipExisting
)

# Initialize logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
}

# Validate prerequisites
function Test-Prerequisites {
    Write-Log "Validating prerequisites..."
    
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

# Create resource group
function New-ChaosResourceGroup {
    Write-Log "Creating resource group: $ResourceGroupName in $Location"
    
    try {
        $existingRG = az group show --name $ResourceGroupName --output json 2>$null
        if ($existingRG -and -not $SkipExisting) {
            Write-Log "Resource group already exists. Use -SkipExisting to skip."
            return
        }
        
        az group create --name $ResourceGroupName --location $Location
        Write-Log "Resource group created successfully."
    }
    catch {
        Write-Log "Failed to create resource group: $_" "ERROR"
        throw
    }
}

# Create Log Analytics Workspace
function New-LogAnalyticsWorkspace {
    Write-Log "Creating Log Analytics Workspace: $LogAnalyticsWorkspaceName"
    
    try {
        $existingWorkspace = az monitor log-analytics workspace show `
            --resource-group $ResourceGroupName `
            --workspace-name $LogAnalyticsWorkspaceName `
            --output json 2>$null
        
        if ($existingWorkspace -and -not $SkipExisting) {
            Write-Log "Log Analytics Workspace already exists."
            return (ConvertFrom-Json $existingWorkspace).customerId
        }
        
        $workspace = az monitor log-analytics workspace create `
            --resource-group $ResourceGroupName `
            --workspace-name $LogAnalyticsWorkspaceName `
            --location $Location `
            --output json | ConvertFrom-Json
        
        Write-Log "Log Analytics Workspace created successfully."
        return $workspace.customerId
    }
    catch {
        Write-Log "Failed to create Log Analytics Workspace: $_" "ERROR"
        throw
    }
}

# Create Application Insights
function New-ApplicationInsights {
    param([string]$WorkspaceId)
    
    Write-Log "Creating Application Insights: $AppInsightsName"
    
    try {
        $existingAppInsights = az monitor app-insights component show `
            --resource-group $ResourceGroupName `
            --app $AppInsightsName `
            --output json 2>$null
        
        if ($existingAppInsights -and -not $SkipExisting) {
            Write-Log "Application Insights already exists."
            return (ConvertFrom-Json $existingAppInsights).appId
        }
        
        $appInsights = az monitor app-insights component create `
            --resource-group $ResourceGroupName `
            --app $AppInsightsName `
            --location $Location `
            --application-type web `
            --workspace $WorkspaceId `
            --output json | ConvertFrom-Json
        
        Write-Log "Application Insights created successfully."
        return $appInsights.appId
    }
    catch {
        Write-Log "Failed to create Application Insights: $_" "ERROR"
        throw
    }
}

# Create Service Principal for Chaos Experiments
function New-ChaosServicePrincipal {
    Write-Log "Creating Service Principal for Chaos Experiments"
    
    try {
        $spName = "chaos-experiments-sp"
        $existingSP = az ad sp show --id "http://$spName" --output json 2>$null
        
        if ($existingSP -and -not $SkipExisting) {
            Write-Log "Service Principal already exists."
            $sp = ConvertFrom-Json $existingSP
        } else {
            $sp = az ad sp create-for-rbac `
                --name $spName `
                --role "Contributor" `
                --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName" `
                --output json | ConvertFrom-Json
            
            Write-Log "Service Principal created successfully."
        }
        
        # Store credentials securely
        $spCredentials = @{
            clientId = $sp.appId
            clientSecret = $sp.password
            tenantId = $sp.tenant
            subscriptionId = (az account show --query id -o tsv)
        }
        
        $spCredentials | ConvertTo-Json | Out-File -FilePath "config/service-principal.json" -Encoding UTF8
        Write-Log "Service Principal credentials saved to config/service-principal.json"
        
        return $sp.appId
    }
    catch {
        Write-Log "Failed to create Service Principal: $_" "ERROR"
        throw
    }
}

# Create Key Vault for secrets
function New-KeyVault {
    param([string]$ServicePrincipalId)
    
    $keyVaultName = "chaos-kv-$(Get-Random -Maximum 9999)"
    Write-Log "Creating Key Vault: $keyVaultName"
    
    try {
        $existingKV = az keyvault show `
            --resource-group $ResourceGroupName `
            --name $keyVaultName `
            --output json 2>$null
        
        if ($existingKV -and -not $SkipExisting) {
            Write-Log "Key Vault already exists."
            return $keyVaultName
        }
        
        az keyvault create `
            --resource-group $ResourceGroupName `
            --name $keyVaultName `
            --location $Location `
            --enabled-for-template-deployment true
        
        # Add access policy for Service Principal
        az keyvault set-policy `
            --name $keyVaultName `
            --spn $ServicePrincipalId `
            --secret-permissions get list set delete
        
        Write-Log "Key Vault created successfully."
        return $keyVaultName
    }
    catch {
        Write-Log "Failed to create Key Vault: $_" "ERROR"
        throw
    }
}

# Create Azure Monitor alerts for chaos experiments
function New-ChaosAlerts {
    param([string]$WorkspaceId)
    
    Write-Log "Creating Azure Monitor alerts for chaos experiments"
    
    try {
        # High error rate alert
        az monitor metrics alert create `
            --name "Chaos-Experiment-High-Error-Rate" `
            --resource-group $ResourceGroupName `
            --scopes $WorkspaceId `
            --condition "avg exceptions/count > 10" `
            --window-size 5m `
            --evaluation-frequency 1m `
            --severity 2 `
            --description "High error rate detected during chaos experiment"
        
        # High response time alert
        az monitor metrics alert create `
            --name "Chaos-Experiment-High-Response-Time" `
            --resource-group $ResourceGroupName `
            --scopes $WorkspaceId `
            --condition "avg requests/duration > 2000" `
            --window-size 5m `
            --evaluation-frequency 1m `
            --severity 3 `
            --description "High response time detected during chaos experiment"
        
        Write-Log "Azure Monitor alerts created successfully."
    }
    catch {
        Write-Log "Failed to create Azure Monitor alerts: $_" "WARNING"
    }
}

# Update configuration file
function Update-Configuration {
    param(
        [string]$WorkspaceId,
        [string]$AppInsightsId,
        [string]$KeyVaultName
    )
    
    Write-Log "Updating configuration file..."
    
    try {
        $configPath = "config/chaos-config.yaml"
        $configContent = Get-Content $configPath -Raw
        
        # Update configuration with actual values
        $configContent = $configContent -replace 'subscription_id: ""', "subscription_id: `$(az account show --query id -o tsv)"
        $configContent = $configContent -replace 'resource_group: ""', "resource_group: $ResourceGroupName"
        $configContent = $configContent -replace 'location: ""', "location: $Location"
        $configContent = $configContent -replace 'workspace_id: ""', "workspace_id: $WorkspaceId"
        
        $configContent | Out-File -FilePath $configPath -Encoding UTF8
        Write-Log "Configuration file updated successfully."
    }
    catch {
        Write-Log "Failed to update configuration file: $_" "WARNING"
    }
}

# Create example chaos experiment
function New-ExampleExperiment {
    Write-Log "Creating example chaos experiment..."
    
    try {
        $exampleDir = "examples"
        if (!(Test-Path $exampleDir)) {
            New-Item -ItemType Directory -Path $exampleDir
        }
        
        $exampleExperiment = @"
# Example Chaos Experiment
# This is a sample experiment configuration

apiVersion: chaosstudio.io/v1beta1
kind: Experiment
metadata:
  name: example-experiment
  namespace: chaos-testing
spec:
  steps:
    - name: example-step
      type: VirtualMachineNetworkLatency
      duration: "PT2M"
      parameters:
        targetResourceType: "Microsoft.Compute/virtualMachines"
        targetResources:
          - "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/example-vm"
        latencyInMilliseconds: 50
        jitterInMilliseconds: 5
        correlationFactor: 20
"@
        
        $exampleExperiment | Out-File -FilePath "$exampleDir/example-experiment.yaml" -Encoding UTF8
        Write-Log "Example experiment created: examples/example-experiment.yaml"
    }
    catch {
        Write-Log "Failed to create example experiment: $_" "WARNING"
    }
}

# Main deployment execution
try {
    Write-Log "Starting Chaos Engineering Infrastructure Deployment"
    Write-Log "Resource Group: $ResourceGroupName, Location: $Location"
    
    # Create directories
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" }
    if (!(Test-Path "config")) { New-Item -ItemType Directory -Path "config" }
    if (!(Test-Path "examples")) { New-Item -ItemType Directory -Path "examples" }
    
    # Execute deployment steps
    Test-Prerequisites
    New-ChaosResourceGroup
    $workspaceId = New-LogAnalyticsWorkspace
    $appInsightsId = New-ApplicationInsights -WorkspaceId $workspaceId
    $spId = New-ChaosServicePrincipal
    $keyVaultName = New-KeyVault -ServicePrincipalId $spId
    New-ChaosAlerts -WorkspaceId $workspaceId
    Update-Configuration -WorkspaceId $workspaceId -AppInsightsId $appInsightsId -KeyVaultName $keyVaultName
    New-ExampleExperiment
    
    Write-Log "Chaos Engineering Infrastructure deployment completed successfully!"
    Write-Log ""
    Write-Log "Next Steps:"
    Write-Log "1. Review the generated configuration in config/chaos-config.yaml"
    Write-Log "2. Update the configuration with your specific resource details"
    Write-Log "3. Test the infrastructure by running a simple chaos experiment"
    Write-Log "4. Check the Service Principal credentials in config/service-principal.json"
    Write-Log ""
    Write-Log "Important: Secure the service-principal.json file and update the configuration with your specific resource details."
}
catch {
    Write-Log "Deployment failed: $_" "ERROR"
    exit 1
}
