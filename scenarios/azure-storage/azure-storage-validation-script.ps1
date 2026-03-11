# Azure Storage Chaos Validation Script
# Validates Storage account functionality during chaos experiments

param(
    [string]$ResourceGroup = "",
    [string]$StorageAccountName = "",
    [string]$TestContainerName = "chaos-test-container",
    [string]$TestQueueName = "chaos-test-queue",
    [string]$TestTableName = "chaos-test-table",
    [string]$TestFileShareName = "chaos-test-share"
)

# Install required modules
if (-not (Get-Module -ListAvailable -Name Az.Storage)) {
    Install-Module -Name Az.Storage -Force -Scope CurrentUser
}

# Initialize logging
$logPath = "C:\temp\azure-storage-chaos-validation.log"
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $Message"
    Write-Host $Message
}

# Test Storage account basic connectivity
function Test-StorageConnectivity {
    Write-Log "Testing Storage account connectivity..."
    
    try {
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName
        Write-Log "✓ Storage account found: $($storageAccount.StorageAccountName)"
        Write-Log "Location: $($storageAccount.Location)"
        Write-Log "SKU: $($storageAccount.Sku.Name)"
        Write-Log "Kind: $($storageAccount.Kind)"
        Write-Log "Primary endpoint: $($storageAccount.PrimaryEndpoints.Blob)"
        
        # Get storage context
        $storageKeys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroup -Name $StorageAccountName
        $script:storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageKeys[0].Value
        Write-Log "✓ Storage context created successfully"
        
        return $true
    }
    catch {
        Write-Log "✗ Storage account connectivity failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Blob storage operations
function Test-BlobStorage {
    Write-Log "Testing Blob storage operations..."
    
    try {
        # Create test container
        New-AzStorageContainer -Name $TestContainerName -Context $script:storageContext -Permission Container -ErrorAction SilentlyContinue
        Write-Log "✓ Created test container: $TestContainerName"
        
        # Test blob upload
        $testBlobName = "chaos-test-$(Get-Date -Format 'yyyyMMddHHmmss').txt"
        $testContent = "Chaos test content $(Get-Date)"
        Set-AzStorageBlobContent -Container $TestContainerName -Blob $testBlobName -Context $script:storageContext -Value $testContent -Force
        Write-Log "✓ Uploaded test blob: $testBlobName"
        
        # Test blob download
        $downloadedBlob = Get-AzStorageBlobContent -Container $TestContainerName -Blob $testBlobName -Context $script:storageContext -Force
        $downloadedContent = Get-Content -Path $downloadedBlob.FullName
        if ($downloadedContent -eq $testContent) {
            Write-Log "✓ Blob download and content verification successful"
        } else {
            Write-Log "✗ Blob content mismatch"
            return $false
        }
        
        # Test blob listing
        $blobs = Get-AzStorageBlob -Container $TestContainerName -Context $script:storageContext
        Write-Log "✓ Found $($blobs.Count) blobs in container"
        
        # Test blob properties
        $blobProperties = Get-AzStorageBlob -Container $TestContainerName -Blob $testBlobName -Context $script:storageContext | Get-AzStorageBlobProperty
        Write-Log "✓ Retrieved blob properties - Size: $($blobProperties.Length) bytes"
        
        # Test blob copy
        $copyBlobName = "copy-$testBlobName"
        Start-AzStorageBlobCopy -SrcBlob $testBlobName -SrcContainer $TestContainerName -DestContainer $TestContainerName -DestBlob $copyBlobName -Context $script:storageContext
        Write-Log "✓ Initiated blob copy operation"
        
        # Clean up test blobs
        Remove-AzStorageBlob -Container $TestContainerName -Blob $testBlobName -Context $script:storageContext -Force -ErrorAction SilentlyContinue
        Remove-AzStorageBlob -Container $TestContainerName -Blob $copyBlobName -Context $script:storageContext -Force -ErrorAction SilentlyContinue
        Write-Log "✓ Cleaned up test blobs"
        
        return $true
    }
    catch {
        Write-Log "✗ Blob storage operations failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Queue storage operations
function Test-QueueStorage {
    Write-Log "Testing Queue storage operations..."
    
    try {
        # Create test queue
        New-AzStorageQueue -Name $TestQueueName -Context $script:storageContext -ErrorAction SilentlyContinue
        Write-Log "✓ Created test queue: $TestQueueName"
        
        # Test message enqueue
        $queue = Get-AzStorageQueue -Name $TestQueueName -Context $script:storageContext
        $testMessage = "Chaos test message $(Get-Date)"
        $queue.CloudQueue.AddMessage($testMessage)
        Write-Log "✓ Enqueued test message"
        
        # Test message peek
        $peekedMessages = $queue.CloudQueue.PeekMessages(1)
        if ($peekedMessages.Count -gt 0) {
            Write-Log "✓ Peeked message content: $($peekedMessages[0].AsString)"
        } else {
            Write-Log "✗ No messages found in queue"
            return $false
        }
        
        # Test message dequeue
        $receivedMessages = $queue.CloudQueue.GetMessages(1)
        if ($receivedMessages.Count -gt 0) {
            $queue.CloudQueue.DeleteMessage($receivedMessages[0])
            Write-Log "✓ Dequeued and deleted message"
        } else {
            Write-Log "✗ No messages available for dequeue"
            return $false
        }
        
        # Test queue properties
        $queueProperties = $queue.CloudQueue.FetchAttributes()
        Write-Log "✓ Queue properties - Approximate message count: $($queueProperties.ApproximateMessageCount)"
        
        # Clean up test queue
        Remove-AzStorageQueue -Name $TestQueueName -Context $script:storageContext -Force -ErrorAction SilentlyContinue
        Write-Log "✓ Cleaned up test queue"
        
        return $true
    }
    catch {
        Write-Log "✗ Queue storage operations failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Table storage operations
function Test-TableStorage {
    Write-Log "Testing Table storage operations..."
    
    try {
        # Check if Table storage is supported (depends on account kind)
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName
        
        if ($storageAccount.Kind -ne "StorageV2" -and $storageAccount.Kind -ne "Storage") {
            Write-Log "⚠ Table storage not supported for account kind: $($storageAccount.Kind)"
            return $true
        }
        
        # Create test table
        New-AzStorageTable -Name $TestTableName -Context $script:storageContext -ErrorAction SilentlyContinue
        Write-Log "✓ Created test table: $TestTableName"
        
        # Test entity insert
        $partitionKey = "chaos-test"
        $rowKey = "test-$(Get-Date -Format 'yyyyMMddHHmmss')"
        $entity = New-Object "Microsoft.WindowsAzure.Storage.Table.TableEntity" $partitionKey, $rowKey
        $entity.Properties["TestProperty"] = "TestValue"
        $entity.Properties["Timestamp"] = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        $table = Get-AzStorageTable -Name $TestTableName -Context $script:storageContext
        $result = $table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Insert($entity))
        Write-Log "✓ Inserted test entity"
        
        # Test entity query
        $query = New-Object "Microsoft.WindowsAzure.Storage.Table.TableQuery"
        $query.FilterString = "PartitionKey eq '$partitionKey'"
        $entities = $table.CloudTable.ExecuteQuery($query)
        
        if ($entities.Count -gt 0) {
            Write-Log "✓ Queried entities - Found $($entities.Count) entities"
        } else {
            Write-Log "✗ No entities found in table"
            return $false
        }
        
        # Test entity update
        $entity.Properties["TestProperty"] = "UpdatedValue"
        $updateResult = $table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Replace($entity))
        Write-Log "✓ Updated test entity"
        
        # Test entity delete
        $deleteResult = $table.CloudTable.Execute([Microsoft.WindowsAzure.Storage.Table.TableOperation]::Delete($entity))
        Write-Log "✓ Deleted test entity"
        
        # Clean up test table
        Remove-AzStorageTable -Name $TestTableName -Context $script:storageContext -Force -ErrorAction SilentlyContinue
        Write-Log "✓ Cleaned up test table"
        
        return $true
    }
    catch {
        Write-Log "✗ Table storage operations failed: $($_.Exception.Message)"
        return $false
    }
}

# Test File share operations
function Test-FileShare {
    Write-Log "Testing File share operations..."
    
    try {
        # Create test file share
        New-AzStorageShare -Name $TestFileShareName -Context $script:storageContext -ErrorAction SilentlyContinue
        Write-Log "✓ Created test file share: $TestFileShareName"
        
        # Test directory creation
        $testDirectory = "chaos-test-dir"
        New-AzStorageDirectory -ShareName $TestFileShareName -Path $testDirectory -Context $script:storageContext
        Write-Log "✓ Created test directory: $testDirectory"
        
        # Test file upload
        $testFileName = "chaos-test-file.txt"
        $testContent = "Chaos test file content $(Get-Date)"
        Set-AzStorageFileContent -ShareName $TestFileShareName -Source $testContent -Path "$testDirectory/$testFileName" -Context $script:storageContext -Force
        Write-Log "✓ Uploaded test file: $testFileName"
        
        # Test file download
        $downloadedFile = Get-AzStorageFileContent -ShareName $TestFileShareName -Path "$testDirectory/$testFileName" -Context $script:storageContext
        $downloadedContent = Get-Content -Path $downloadedFile.FullName
        if ($downloadedContent -eq $testContent) {
            Write-Log "✓ File download and content verification successful"
        } else {
            Write-Log "✗ File content mismatch"
            return $false
        }
        
        # Test file listing
        $files = Get-AzStorageFile -ShareName $TestFileShareName -Path $testDirectory -Context $script:storageContext
        Write-Log "✓ Found $($files.Count) files in directory"
        
        # Test share properties
        $shareProperties = Get-AzStorageShare -ShareName $TestFileShareName -Context $script:storageContext | Get-AzStorageShareProperty
        Write-Log "✓ Share properties - Quota: $($shareProperties.Quota) GB"
        
        # Clean up test file share
        Remove-AzStorageShare -Name $TestFileShareName -Context $script:storageContext -Force -ErrorAction SilentlyContinue
        Write-Log "✓ Cleaned up test file share"
        
        return $true
    }
    catch {
        Write-Log "✗ File share operations failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Storage account redundancy and replication
function Test-StorageRedundancy {
    Write-Log "Testing Storage account redundancy and replication..."
    
    try {
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName
        
        Write-Log "✓ Redundancy: $($storageAccount.Sku.Tier) $($storageAccount.Sku.Name)"
        
        # Check geo-replication status
        if ($storageAccount.Sku.Name -like "*GRS*" -or $storageAccount.Sku.Name -like "*GZRS*") {
            try {
                $geoReplicationStats = Get-AzStorageServiceLogProperty -Context $script:storageContext
                Write-Log "✓ Geo-replication status available"
                
                # Check last sync time
                if ($geoReplicationStats.GeoReplication.LastSyncTime) {
                    Write-Log "✓ Last sync time: $($geoReplicationStats.GeoReplication.LastSyncTime)"
                }
            }
            catch {
                Write-Log "⚠ Could not retrieve geo-replication statistics"
            }
        }
        
        # Check availability
        try {
            $availability = Get-AzStorageServiceMetricsProperty -ServiceType Blob -Context $script:storageContext
            Write-Log "✓ Storage service metrics available"
        }
        catch {
            Write-Log "⚠ Could not retrieve storage service metrics"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Storage redundancy test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Storage account security features
function Test-StorageSecurity {
    Write-Log "Testing Storage account security features..."
    
    try {
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName
        
        # Check HTTPS requirement
        Write-Log "✓ HTTPS traffic only: $($storageAccount.EnableHttpsTrafficOnly)"
        
        # Check network rules
        if ($storageAccount.NetworkRuleSet) {
            $networkRules = $storageAccount.NetworkRuleSet
            Write-Log "✓ Network rules configured"
            Write-Log "  - Default action: $($networkRules.DefaultAction)"
            Write-Log "  - Bypass: $($networkRules.Bypass)"
            
            if ($networkRules.IpRules) {
                Write-Log "  - IP rules: $($networkRules.IpRules.Count)"
            }
            
            if ($networkRules.VirtualNetworkRules) {
                Write-Log "  - Virtual network rules: $($networkRules.VirtualNetworkRules.Count)"
            }
        } else {
            Write-Log "⚠ No network rules configured"
        }
        
        # Check private endpoints
        try {
            $privateEndpoints = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $storageAccount.Id
            if ($privateEndpoints.Count -gt 0) {
                Write-Log "✓ Found $($privateEndpoints.Count) private endpoint connections"
            } else {
                Write-Log "⚠ No private endpoint connections found"
            }
        }
        catch {
            Write-Log "⚠ Could not check private endpoint connections"
        }
        
        # Check encryption
        Write-Log "✓ Encryption: $($storageAccount.Encryption.KeySource)"
        if ($storageAccount.Encryption.Services) {
            $encryptionServices = $storageAccount.Encryption.Services | Where-Object { $_.Enabled -eq $true }
            Write-Log "✓ Encrypted services: $($encryptionServices | ForEach-Object { $_.Service } -join ', ')"
        }
        
        return $true
    }
    catch {
        Write-Log "✗ Storage security test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test Storage account access management
function Test-StorageAccessManagement {
    Write-Log "Testing Storage account access management..."
    
    try {
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName
        
        # Check access keys
        $storageKeys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroup -Name $StorageAccountName
        Write-Log "✓ Found $($storageKeys.Count) access keys"
        
        # Test SAS token generation
        $containerName = "sas-test"
        New-AzStorageContainer -Name $containerName -Context $script:storageContext -ErrorAction SilentlyContinue
        
        $sasToken = New-AzStorageContainerSASToken -Name $containerName -Context $script:storageContext -Permission "rwdl" -StartTime (Get-Date) -ExpiryTime (Get-Date).AddHours(1)
        Write-Log "✓ Generated SAS token for container access"
        
        # Test Managed Identity access (if applicable)
        try {
            $managedIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroup -ErrorAction SilentlyContinue
            if ($managedIdentity) {
                Write-Log "✓ Managed identities available in resource group"
            }
        }
        catch {
            Write-Log "⚠ No managed identities found"
        }
        
        # Clean up
        Remove-AzStorageContainer -Name $containerName -Context $script:storageContext -Force -ErrorAction SilentlyContinue
        
        return $true
    }
    catch {
        Write-Log "✗ Storage access management test failed: $($_.Exception.Message)"
        return $false
    }
}

# Get Storage account metrics
function Get-StorageMetrics {
    Write-Log "Collecting Storage account metrics..."
    
    try {
        $resourceId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroup/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"
        
        $metrics = @()
        
        # Availability
        try {
            $availability = Get-AzMetric -ResourceId $resourceId -MetricNames "Availability" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "Availability"
                Value = ($availability | Select-Object -Last 1).Data.Average
                Unit = "Percent"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve Availability metric"
        }
        
        # Ingress
        try {
            $ingress = Get-AzMetric -ResourceId $resourceId -MetricNames "Ingress" -TimeGrain 00:01:00 -AggregationType Total
            $metrics += @{
                Name = "Ingress"
                Value = ($ingress | Select-Object -Last 1).Data.Total
                Unit = "Bytes"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve Ingress metric"
        }
        
        # Egress
        try {
            $egress = Get-AzMetric -ResourceId $resourceId -MetricNames "Egress" -TimeGrain 00:01:00 -AggregationType Total
            $metrics += @{
                Name = "Egress"
                Value = ($egress | Select-Object -Last 1).Data.Total
                Unit = "Bytes"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve Egress metric"
        }
        
        # Transactions
        try {
            $transactions = Get-AzMetric -ResourceId $resourceId -MetricNames "Transactions" -TimeGrain 00:01:00 -AggregationType Total
            $metrics += @{
                Name = "Transactions"
                Value = ($transactions | Select-Object -Last 1).Data.Total
                Unit = "Count"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve Transactions metric"
        }
        
        # Success Rate
        try {
            $successRate = Get-AzMetric -ResourceId $resourceId -MetricNames "SuccessE2ELatency" -TimeGrain 00:01:00 -AggregationType Average
            $metrics += @{
                Name = "SuccessE2ELatency"
                Value = ($successRate | Select-Object -Last 1).Data.Average
                Unit = "Milliseconds"
            }
        }
        catch {
            Write-Log "⚠ Could not retrieve SuccessE2ELatency metric"
        }
        
        return $metrics
    }
    catch {
        Write-Log "✗ Failed to collect metrics: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
Write-Log "Starting Azure Storage chaos validation..."
Write-Log "Resource Group: $ResourceGroup"
Write-Log "Storage Account: $StorageAccountName"
Write-Log "Test Container: $TestContainerName"
Write-Log "Test Queue: $TestQueueName"
Write-Log "Test Table: $TestTableName"
Write-Log "Test File Share: $TestFileShareName"

$testResults = @()

# Run all tests
$testResults += @{ Test = "Connectivity"; Result = (Test-StorageConnectivity) }
$testResults += @{ Test = "BlobStorage"; Result = (Test-BlobStorage) }
$testResults += @{ Test = "QueueStorage"; Result = (Test-QueueStorage) }
$testResults += @{ Test = "TableStorage"; Result = (Test-TableStorage) }
$testResults += @{ Test = "FileShare"; Result = (Test-FileShare) }
$testResults += @{ Test = "Redundancy"; Result = (Test-StorageRedundancy) }
$testResults += @{ Test = "Security"; Result = (Test-StorageSecurity) }
$testResults += @{ Test = "AccessManagement"; Result = (Test-StorageAccessManagement) }

# Get metrics
$metrics = Get-StorageMetrics

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
    Write-Log "All tests passed - Storage account healthy"
    exit 0
} else {
    Write-Log "Some tests failed - Storage account issues detected"
    exit 1
}
