# Transaction Chaos Validation Script
# Validates application transaction integrity during chaos experiments

param(
    [string]$ResourceGroup = "",
    [string]$AppServiceName = "",
    [string]$SqlServerName = "",
    [string]$DatabaseName = ""
)

# Install required modules
if (-not (Get-Module -ListAvailable -Name Az.Sql)) {
    Install-Module -Name Az.Sql -Force -Scope CurrentUser
}

# Initialize logging
$logPath = "C:\temp\transaction-chaos-validation.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $Message"
    Write-Host $Message
}

# Test database connectivity and transaction integrity
function Test-DatabaseTransactions {
    Write-Log "Testing database transaction integrity..."
    
    try {
        $connectionString = "Server=$SqlServerName.database.windows.net;Database=$DatabaseName;Integrated Security=true;"
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        
        # Test basic transaction
        $transaction = $connection.BeginTransaction()
        $command = $connection.CreateCommand()
        $command.Transaction = $transaction
        
        try {
            # Insert test record
            $command.CommandText = "INSERT INTO ChaosTest (TestID, Timestamp, Status) VALUES (NEWID(), GETUTCDATE(), 'PENDING')"
            $command.ExecuteNonQuery()
            
            # Simulate some processing
            Start-Sleep -Seconds 2
            
            # Update record
            $command.CommandText = "UPDATE ChaosTest SET Status = 'COMPLETED' WHERE Status = 'PENDING'"
            $command.ExecuteNonQuery()
            
            # Commit transaction
            $transaction.Commit()
            Write-Log "✓ Transaction committed successfully"
            return $true
        }
        catch {
            $transaction.Rollback()
            Write-Log "✗ Transaction failed and rolled back: $($_.Exception.Message)"
            return $false
        }
        finally {
            $connection.Close()
        }
    }
    catch {
        Write-Log "✗ Database connection failed: $($_.Exception.Message)"
        return $false
    }
}

# Test distributed transaction consistency
function Test-DistributedTransactions {
    Write-Log "Testing distributed transaction consistency..."
    
    try {
        # Test across multiple databases/services
        $testResults = @()
        
        # Primary database test
        $primaryResult = Test-DatabaseTransactions
        $testResults += @{ Service = "PrimaryDB"; Status = $primaryResult }
        
        # Secondary service test (if applicable)
        if ($AppServiceName) {
            $appServiceUrl = "https://$AppServiceName.azurewebsites.net/api/health"
            try {
                $response = Invoke-RestMethod -Uri $appServiceUrl -Method Get -TimeoutSec 10
                $testResults += @{ Service = "AppService"; Status = ($response.status -eq "healthy") }
            }
            catch {
                $testResults += @{ Service = "AppService"; Status = $false }
            }
        }
        
        # Check consistency
        $allHealthy = $testResults.Where({ $_.Status -eq $true }).Count -eq $testResults.Count
        if ($allHealthy) {
            Write-Log "✓ All distributed services healthy"
        } else {
            Write-Log "✗ Some distributed services unhealthy:"
            $testResults.Where({ $_.Status -eq $false }).ForEach({ Write-Log "  - $($_.Service)" })
        }
        
        return $allHealthy
    }
    catch {
        Write-Log "✗ Distributed transaction test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test transaction rollback scenarios
function Test-TransactionRollback {
    Write-Log "Testing transaction rollback scenarios..."
    
    try {
        $connectionString = "Server=$SqlServerName.database.windows.net;Database=$DatabaseName;Integrated Security=true;"
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        
        # Create transaction that will fail
        $transaction = $connection.BeginTransaction()
        $command = $connection.CreateCommand()
        $command.Transaction = $transaction
        
        try {
            # Insert test record
            $command.CommandText = "INSERT INTO ChaosTest (TestID, Timestamp, Status) VALUES (NEWID(), GETUTCDATE(), 'ROLLBACK_TEST')"
            $command.ExecuteNonQuery()
            
            # Force an error
            $command.CommandText = "INSERT INTO ChaosTest (TestID, Timestamp, Status) VALUES ('INVALID-ID', GETUTCDATE(), 'ERROR')"
            $command.ExecuteNonQuery()
            
            $transaction.Commit()
            Write-Log "✗ Unexpected: Transaction should have failed"
            return $false
        }
        catch {
            $transaction.Rollback()
            
            # Verify rollback worked
            $checkCommand = $connection.CreateCommand()
            $checkCommand.CommandText = "SELECT COUNT(*) FROM ChaosTest WHERE Status = 'ROLLBACK_TEST'"
            $count = $checkCommand.ExecuteScalar()
            
            if ($count -eq 0) {
                Write-Log "✓ Transaction rollback successful"
                return $true
            } else {
                Write-Log "✗ Transaction rollback failed - records still exist"
                return $false
            }
        }
        finally {
            $connection.Close()
        }
    }
    catch {
        Write-Log "✗ Transaction rollback test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test connection pool behavior
function Test-ConnectionPool {
    Write-Log "Testing connection pool behavior..."
    
    try {
        $connectionString = "Server=$SqlServerName.database.windows.net;Database=$DatabaseName;Integrated Security=true;Max Pool Size=10;"
        $connectionTasks = @()
        
        # Create multiple concurrent connections
        for ($i = 1; $i -le 15; $i++) {
            $connectionTasks += {
                param($connStr, $index)
                try {
                    $conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
                    $conn.Open()
                    Start-Sleep -Seconds 2
                    $conn.Close()
                    return $true
                }
                catch {
                    return $false
                }
            }.GetNewClosure().Invoke($connectionString, $i)
        }
        
        # Run all connection tasks
        $results = $connectionTasks | ForEach-Object { & $_ }
        $successfulConnections = ($results | Where-Object { $_ -eq $true }).Count
        
        if ($successfulConnections -ge 10) {
            Write-Log "✓ Connection pool working correctly ($successfulConnections/15 successful)"
            return $true
        } else {
            Write-Log "✗ Connection pool issues detected ($successfulConnections/15 successful)"
            return $false
        }
    }
    catch {
        Write-Log "✗ Connection pool test failed: $($_.Exception.Message)"
        return $false
    }
}

# Monitor transaction metrics
function Get-TransactionMetrics {
    Write-Log "Collecting transaction metrics..."
    
    try {
        $metrics = @()
        
        # Database metrics
        if ($SqlServerName -and $DatabaseName) {
            $dbMetrics = Get-AzSqlDatabaseActivityMetric -ResourceGroupName $ResourceGroup -ServerName $SqlServerName -DatabaseName $DatabaseName
            $metrics += @{
                Type = "Database"
                Metric = "ActiveConnections"
                Value = ($dbMetrics | Where-Object { $_.Name -eq "active_connections" }).Total
            }
        }
        
        # App Service metrics
        if ($AppServiceName) {
            $appMetrics = Get-AzMetric -ResourceId "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$AppServiceName" -MetricNames "Http5xx" -TimeGrain 00:01:00
            $metrics += @{
                Type = "AppService"
                Metric = "Http5xx"
                Value = ($appMetrics | Select-Object -Last 1).Data.Maximum
            }
        }
        
        return $metrics
    }
    catch {
        Write-Log "✗ Failed to collect metrics: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
Write-Log "Starting transaction chaos validation..."
Write-Log "Resource Group: $ResourceGroup"
Write-Log "App Service: $AppServiceName"
Write-Log "SQL Server: $SqlServerName"
Write-Log "Database: $DatabaseName"

$testResults = @()

# Run all tests
$testResults += @{ Test = "DatabaseTransactions"; Result = (Test-DatabaseTransactions) }
$testResults += @{ Test = "DistributedTransactions"; Result = (Test-DistributedTransactions) }
$testResults += @{ Test = "TransactionRollback"; Result = (Test-TransactionRollback) }
$testResults += @{ Test = "ConnectionPool"; Result = (Test-ConnectionPool) }

# Get metrics
$metrics = Get-TransactionMetrics

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
        Write-Log "$($metric.Type).$($metric.Metric): $($metric.Value)"
    }
}

# Return exit code
if ($passedTests -eq $totalTests) {
    Write-Log "All tests passed - transaction integrity maintained"
    exit 0
} else {
    Write-Log "Some tests failed - transaction integrity compromised"
    exit 1
}
