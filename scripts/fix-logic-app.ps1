# Fix StreamBridge Logic App - Sets Cosmos Connection String
param (
    [string]$SubscriptionId = "4b27ac87-dec6-45d5-8634-b9f71bd1dd26",
    [string]$ResourceGroup = "rg-streambridge",
    [string]$LogicAppName = "streambridgelogicbryctld4qwjpg",
    [string]$CosmosAccountName = "streambridgecosmosbryctld4qwjpg"
)

Write-Host "[STREAMBRIDGE] Logic App Connection Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Authenticate
Write-Host "[AUTH] Authenticating to Azure..." -ForegroundColor Yellow
$context = Get-AzContext
if (-not $context) {
    Connect-AzAccount -SubscriptionId $SubscriptionId | Out-Null
    $context = Get-AzContext
}
Write-Host "[OK] Connected to subscription: $($context.Subscription.Name)" -ForegroundColor Green

# Set subscription
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

# Get Cosmos Master Key
Write-Host ""
Write-Host "[COSMOS] Retrieving Cosmos DB Master Key..." -ForegroundColor Yellow
try {
    $cosmosKeys = Get-AzCosmosDBAccountKey `
        -ResourceGroupName $ResourceGroup `
        -Name $CosmosAccountName -ErrorAction Stop

    $primaryKey = $cosmosKeys.PrimaryMasterKey
    $cosmosConnStr = "AccountEndpoint=https://${CosmosAccountName}.documents.azure.com:443/;AccountKey=${primaryKey};"
    Write-Host "[OK] Cosmos connection string prepared (Length: $($cosmosConnStr.Length) chars)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to get Cosmos keys: $_" -ForegroundColor Red
    exit 1
}

# Update Logic App
Write-Host ""
Write-Host "[LOGIC] Updating Logic App Workflow..." -ForegroundColor Yellow

try {
    # Get Logic App
    $logicApp = Get-AzLogicApp `
        -ResourceGroupName $ResourceGroup `
        -Name $LogicAppName `
        -ErrorAction Stop

    Write-Host "[OK] Found Logic App: $($logicApp.Name)" -ForegroundColor Green

    # Get the workflow definition
    $definition = $logicApp.Definition
    
    # Update the cosmosConnectionString parameter with the actual connection string
    if ($definition.parameters.cosmosConnectionString) {
        $definition.parameters.cosmosConnectionString.defaultValue = $cosmosConnStr
        Write-Host "[OK] Updated cosmosConnectionString parameter in workflow" -ForegroundColor Green
    }
    else {
        Write-Host "[WARN] cosmosConnectionString parameter not found in workflow definition" -ForegroundColor Yellow
    }

    # Update the Logic App with the modified definition
    Set-AzLogicApp `
        -ResourceGroupName $ResourceGroup `
        -Name $LogicAppName `
        -Definition $definition `
        -Force `
        -ErrorAction Stop | Out-Null

    Write-Host "[OK] Logic App workflow updated successfully!" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to update Logic App: $_" -ForegroundColor Red
    exit 1
}

# Restart Logic App
Write-Host ""
Write-Host "[RESTART] Restarting Logic App..." -ForegroundColor Yellow
try {
    Stop-AzLogicApp -ResourceGroupName $ResourceGroup -Name $LogicAppName -ErrorAction SilentlyContinue | Out-Null
    Start-Sleep -Seconds 3
    Start-AzLogicApp -ResourceGroupName $ResourceGroup -Name $LogicAppName -ErrorAction Stop | Out-Null
    Write-Host "[OK] Logic App restarted" -ForegroundColor Green
}
catch {
    Write-Host "[WARN] Could not restart Logic App automatically. You may need to restart it manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[SUCCESS] FIX COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Wait 30 seconds for the Logic App to fully restart"
Write-Host "2. Test the API again"
Write-Host ""
