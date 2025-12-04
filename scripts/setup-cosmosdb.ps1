# StreamBridge - Cosmos DB Setup Script
# Creates database and container with proper configuration

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [string]$CosmosAccountName,

    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "StreamBridgeDemo",

    [Parameter(Mandatory=$false)]
    [string]$ContainerName = "TelemetryData",

    [Parameter(Mandatory=$false)]
    [string]$PartitionKeyPath = "/region"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "StreamBridge - Cosmos DB Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Get Cosmos DB account if not provided
if (-not $CosmosAccountName) {
    Write-Host "`nFinding Cosmos DB account in resource group..." -ForegroundColor Yellow
    $accounts = az cosmosdb list --resource-group $ResourceGroupName --query "[].name" -o tsv
    if (-not $accounts) {
        Write-Error "No Cosmos DB accounts found in resource group: $ResourceGroupName"
        exit 1
    }
    $CosmosAccountName = $accounts | Select-Object -First 1
    Write-Host "Found Cosmos DB account: $CosmosAccountName" -ForegroundColor Green
}

# Check if database exists
Write-Host "`nChecking for existing database..." -ForegroundColor Yellow
$existingDb = az cosmosdb sql database show `
    --account-name $CosmosAccountName `
    --resource-group $ResourceGroupName `
    --name $DatabaseName `
    --query "name" -o tsv 2>$null

if ($existingDb) {
    Write-Host "Database '$DatabaseName' already exists" -ForegroundColor Green
} else {
    Write-Host "Creating database: $DatabaseName" -ForegroundColor Yellow
    az cosmosdb sql database create `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroupName `
        --name $DatabaseName
    Write-Host "Database created successfully!" -ForegroundColor Green
}

# Check if container exists
Write-Host "`nChecking for existing container..." -ForegroundColor Yellow
$existingContainer = az cosmosdb sql container show `
    --account-name $CosmosAccountName `
    --resource-group $ResourceGroupName `
    --database-name $DatabaseName `
    --name $ContainerName `
    --query "name" -o tsv 2>$null

if ($existingContainer) {
    Write-Host "Container '$ContainerName' already exists" -ForegroundColor Green
} else {
    Write-Host "Creating container: $ContainerName" -ForegroundColor Yellow

    # Create container with indexing policy
    $indexingPolicy = @{
        indexingMode = "consistent"
        automatic = $true
        includedPaths = @(
            @{ path = "/*" }
        )
        excludedPaths = @(
            @{ path = "/_etag/?" }
        )
        compositeIndexes = @(
            @(
                @{ path = "/region"; order = "ascending" },
                @{ path = "/timestamp"; order = "descending" }
            ),
            @(
                @{ path = "/deviceId"; order = "ascending" },
                @{ path = "/timestamp"; order = "descending" }
            )
        )
    }

    $indexingPolicyJson = $indexingPolicy | ConvertTo-Json -Depth 10 -Compress

    az cosmosdb sql container create `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroupName `
        --database-name $DatabaseName `
        --name $ContainerName `
        --partition-key-path $PartitionKeyPath `
        --indexing-policy $indexingPolicyJson

    Write-Host "Container created successfully!" -ForegroundColor Green
}

# Display connection info
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Cosmos DB Configuration Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$endpoint = az cosmosdb show `
    --name $CosmosAccountName `
    --resource-group $ResourceGroupName `
    --query "documentEndpoint" -o tsv

Write-Host "`nConnection Details:" -ForegroundColor Yellow
Write-Host "  Account:    $CosmosAccountName"
Write-Host "  Database:   $DatabaseName"
Write-Host "  Container:  $ContainerName"
Write-Host "  Partition:  $PartitionKeyPath"
Write-Host "  Endpoint:   $endpoint"

# Insert sample document
Write-Host "`n----------------------------------------" -ForegroundColor Gray
Write-Host "Inserting sample telemetry document..." -ForegroundColor Yellow

$sampleDoc = @{
    id = [guid]::NewGuid().ToString()
    deviceId = "demo-device-001"
    region = "eastus"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    telemetryType = "metrics"
    data = @{
        cpu = 35.5
        memory = 62.3
        diskUsage = 45.0
    }
    crashDump = $null
    ingestedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    processingResult = @{
        status = "stored"
        message = "Sample document for demo"
    }
} | ConvertTo-Json -Depth 10

# Get primary key for document insertion
$keys = az cosmosdb keys list `
    --name $CosmosAccountName `
    --resource-group $ResourceGroupName `
    --type keys `
    --query "primaryMasterKey" -o tsv

Write-Host "Sample document prepared (will be inserted via Logic App)" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
