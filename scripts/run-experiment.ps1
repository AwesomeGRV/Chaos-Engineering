# Universal Chaos Experiment Runner
# This script provides a unified interface to run all chaos experiments

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("pod-kill", "network-latency", "region-outage")]
    [string]$ExperimentType,
    
    [Parameter(Mandatory=$false)]
    [hashtable]$Parameters = @{},
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "config/chaos-config.yaml",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$ValidateOnly
)

# Initialize logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path "logs/experiment-runner.log" -Value $LogEntry
}

# Load configuration
function Load-Configuration {
    param([string]$ConfigPath)
    
    try {
        if (!(Test-Path $ConfigPath)) {
            Write-Log "Configuration file not found: $ConfigPath" "ERROR"
            throw "Configuration file not found"
        }
        
        # For simplicity, we'll parse YAML as key-value pairs
        # In production, consider using a proper YAML parser
        $config = @{}
        $content = Get-Content $ConfigPath
        
        foreach ($line in $content) {
            if ($line -match '^\s*([^:]+):\s*(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $config[$key] = $value
            }
        }
        
        Write-Log "Configuration loaded from $ConfigPath"
        return $config
    }
    catch {
        Write-Log "Failed to load configuration: $_" "ERROR"
        throw
    }
}

# Validate experiment prerequisites
function Test-ExperimentPrerequisites {
    param([string]$ExperimentType, [hashtable]$Config)
    
    Write-Log "Validating prerequisites for $ExperimentType experiment..."
    
    # Check required configuration values
    $requiredKeys = @("subscription_id", "resource_group", "location")
    foreach ($key in $requiredKeys) {
        if (-not $Config.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($Config[$key])) {
            Write-Log "Missing required configuration: $key" "ERROR"
            throw "Missing required configuration: $key"
        }
    }
    
    # Check Azure connection
    try {
        $accountInfo = az account show --output json | ConvertFrom-Json
        Write-Log "Connected to Azure subscription: $($accountInfo.name)"
    }
    catch {
        Write-Log "Failed to connect to Azure. Please run 'az login'." "ERROR"
        throw
    }
    
    # Experiment-specific validations
    switch ($ExperimentType) {
        "pod-kill" {
            # Check kubectl
            try {
                $kubectlVersion = kubectl version --client --short
                Write-Log "kubectl version: $kubectlVersion"
            }
            catch {
                Write-Log "kubectl not found. Please install kubectl for pod-kill experiments." "ERROR"
                throw
            }
        }
        
        "network-latency" {
            # Validate VM parameters
            if (-not $Parameters.ContainsKey("TargetVMs")) {
                Write-Log "TargetVMs parameter is required for network-latency experiments." "ERROR"
                throw
            }
        }
        
        "region-outage" {
            # Validate Traffic Manager parameters
            $requiredParams = @("PrimaryResourceGroup", "SecondaryResourceGroup", "TrafficManagerProfile")
            foreach ($param in $requiredParams) {
                if (-not $Parameters.ContainsKey($param)) {
                    Write-Log "$param parameter is required for region-outage experiments." "ERROR"
                    throw
                }
            }
        }
    }
    
    Write-Log "Prerequisites validation completed."
}

# Create experiment hypothesis
function New-ExperimentHypothesis {
    param([string]$ExperimentType, [hashtable]$Parameters)
    
    Write-Log "Creating experiment hypothesis..."
    
    $hypothesisDir = "hypotheses"
    if (!(Test-Path $hypothesisDir)) {
        New-Item -ItemType Directory -Path $hypothesisDir
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $hypothesisFile = "$hypothesisDir/$ExperimentType-hypothesis-$timestamp.md"
    
    # Copy template and customize
    $templatePath = "scenarios/$ExperimentType/hypothesis.md"
    if (Test-Path $templatePath) {
        $content = Get-Content $templatePath -Raw
        
        # Replace placeholders with actual values
        $content = $content -replace '\*\*Date\*\*: ', "**Date**: $(Get-Date -Format 'yyyy-MM-dd')"
        
        $content | Out-File -FilePath $hypothesisFile -Encoding UTF8
        Write-Log "Hypothesis created: $hypothesisFile"
        return $hypothesisFile
    } else {
        Write-Log "Hypothesis template not found for $ExperimentType" "WARNING"
        return $null
    }
}

# Execute experiment
function Invoke-Experiment {
    param([string]$ExperimentType, [hashtable]$Parameters)
    
    Write-Log "Executing $ExperimentType experiment..."
    
    $scriptPath = "scenarios/$ExperimentType/$ExperimentType-script.ps1"
    
    if (!(Test-Path $scriptPath)) {
        Write-Log "Experiment script not found: $scriptPath" "ERROR"
        throw "Experiment script not found"
    }
    
    try {
        # Build parameter string
        $paramString = ""
        foreach ($param in $Parameters.GetEnumerator()) {
            $paramString += "-$($param.Key) `"$($param.Value)`" "
        }
        
        $command = "$scriptPath $paramString"
        Write-Log "Executing: $command"
        
        if ($DryRun) {
            Write-Log "DRY RUN: Would execute: $command"
            return @{ Status = "DryRun" }
        } else {
            # Execute the experiment script
            $result = Invoke-Expression $command
            Write-Log "Experiment completed with result: $result"
            return @{ Status = "Completed", Result = $result }
        }
    }
    catch {
        Write-Log "Experiment execution failed: $_" "ERROR"
        throw
    }
}

# Generate experiment report
function New-ExperimentReport {
    param(
        [string]$ExperimentType,
        [hashtable]$Parameters,
        [object]$ExperimentResult,
        [string]$HypothesisFile
    )
    
    Write-Log "Generating experiment report..."
    
    $reportDir = "reports"
    if (!(Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $reportFile = "$reportDir/$ExperimentType-report-$timestamp.json"
    
    $report = @{
        ExperimentType = $ExperimentType
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Parameters = $Parameters
        Result = $ExperimentResult
        HypothesisFile = $HypothesisFile
        Status = $ExperimentResult.Status
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Log "Report generated: $reportFile"
    
    return $reportFile
}

# Send notifications (placeholder)
function Send-Notification {
    param([string]$ExperimentType, [string]$Status, [string]$ReportFile)
    
    Write-Log "Sending notification for $ExperimentType experiment: $Status"
    
    # This is a placeholder for notification logic
    # You can integrate with:
    # - Email (Send-MailMessage)
    # - Microsoft Teams (Webhook)
    # - Slack (Webhook)
    # - Azure Monitor Alerts
    
    try {
        # Example: Teams webhook notification
        # $webhookUrl = "https://outlook.office.com/webhook/..."
        # $payload = @{
        #     text = "Chaos experiment '$ExperimentType' completed with status: $Status"
        #     attachments = @(@{
        #         title = "Experiment Report"
        #         text = "Report available at: $ReportFile"
        #     })
        # }
        # Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($payload | ConvertTo-Json -Depth 10) -ContentType "application/json"
        
        Write-Log "Notification sent successfully."
    }
    catch {
        Write-Log "Failed to send notification: $_" "WARNING"
    }
}

# Main execution
try {
    Write-Log "Starting Chaos Experiment Runner"
    Write-Log "Experiment Type: $ExperimentType"
    Write-Log "Parameters: $($Parameters | ConvertTo-Json -Compress)"
    
    # Create log directory
    if (!(Test-Path "logs")) { New-Item -ItemType Directory -Path "logs" }
    
    # Load configuration
    $config = Load-Configuration -ConfigPath $ConfigFile
    
    # Validate prerequisites
    if (-not $ValidateOnly) {
        Test-ExperimentPrerequisites -ExperimentType $ExperimentType -Config $config
    }
    
    # Create hypothesis
    $hypothesisFile = New-ExperimentHypothesis -ExperimentType $ExperimentType -Parameters $Parameters
    
    if ($ValidateOnly) {
        Write-Log "Validation completed successfully."
        exit 0
    }
    
    # Execute experiment
    $experimentResult = Invoke-Experiment -ExperimentType $ExperimentType -Parameters $Parameters
    
    # Generate report
    $reportFile = New-ExperimentReport -ExperimentType $ExperimentType -Parameters $Parameters -ExperimentResult $experimentResult -HypothesisFile $hypothesisFile
    
    # Send notification
    Send-Notification -ExperimentType $ExperimentType -Status $experimentResult.Status -ReportFile $reportFile
    
    Write-Log "Chaos Experiment Runner completed successfully!"
    Write-Log "Report available at: $reportFile"
    
    if ($experimentResult.Status -eq "Completed") {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-Log "Chaos Experiment Runner failed: $_" "ERROR"
    exit 1
}
