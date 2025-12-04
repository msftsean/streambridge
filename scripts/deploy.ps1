# StreamBridge - Deployment Script
# Deploys all Azure resources using Bicep

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-streambridge",

    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2",

    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",

    [Parameter(Mandatory=$false)]
    [switch]$SkipResourceGroup,

    [Parameter(Mandatory=$false)]
    [switch]$DeployFunctionCode,

    [Parameter(Mandatory=$false)]
    [switch]$DeployLogicAppWorkflow
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "StreamBridge - Azure Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroupName"
Write-Host "  Location:       $Location"
Write-Host "  Environment:    $Environment"
Write-Host ""

# Check Azure CLI
Write-Host "Checking Azure CLI..." -ForegroundColor Yellow
$azVersion = az version --query '"azure-cli"' -o tsv 2>$null
if (-not $azVersion) {
    Write-Error "Azure CLI not found. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}
Write-Host "Azure CLI version: $azVersion" -ForegroundColor Green

# Check login status
Write-Host "`nChecking Azure login status..." -ForegroundColor Yellow
$account = az account show --query "name" -o tsv 2>$null
if (-not $account) {
    Write-Host "Not logged in. Running 'az login'..." -ForegroundColor Yellow
    az login
    $account = az account show --query "name" -o tsv
}
Write-Host "Logged in to subscription: $account" -ForegroundColor Green

# Create resource group if needed
if (-not $SkipResourceGroup) {
    Write-Host "`nCreating resource group: $ResourceGroupName..." -ForegroundColor Yellow
    az group create `
        --name $ResourceGroupName `
        --location $Location `
        --tags "project=streambridge" "environment=$Environment" | Out-Null
    Write-Host "Resource group created!" -ForegroundColor Green
}

# Deploy Bicep template
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deploying Infrastructure (Bicep)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bicepPath = Join-Path $scriptDir "..\infrastructure\main.bicep"

Write-Host "Deploying from: $bicepPath" -ForegroundColor Yellow
Write-Host "This may take 10-15 minutes..." -ForegroundColor Yellow
Write-Host ""

$deployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $bicepPath `
    --parameters location=$Location environment=$Environment `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed!"
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Infrastructure Deployed Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Display outputs
Write-Host "`nDeployment Outputs:" -ForegroundColor Yellow
Write-Host "  Cosmos Account:  $($deployment.cosmosAccountName.value)"
Write-Host "  Function App:    $($deployment.functionAppName.value)"
Write-Host "  Function URL:    $($deployment.functionAppUrl.value)"
Write-Host "  Logic App:       $($deployment.logicAppName.value)"
Write-Host "  Logic App URL:   $($deployment.logicAppUrl.value)"
Write-Host "  APIM:            $($deployment.apimName.value)"
Write-Host "  API Endpoint:    $($deployment.apiEndpoint.value)"

# Deploy Function App code if requested
if ($DeployFunctionCode) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Deploying Function App Code" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $funcAppPath = Join-Path $scriptDir "..\function-app"
    Push-Location $funcAppPath

    try {
        Write-Host "Publishing to $($deployment.functionAppName.value)..." -ForegroundColor Yellow
        func azure functionapp publish $deployment.functionAppName.value --python
        Write-Host "Function App code deployed!" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

# Deploy Logic App workflow if requested
if ($DeployLogicAppWorkflow) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Deploying Logic App Workflow" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $logicAppPath = Join-Path $scriptDir "..\logic-app"

    Write-Host "Deploying workflow to $($deployment.logicAppName.value)..." -ForegroundColor Yellow

    # Create a zip of the logic app files
    $zipPath = Join-Path $env:TEMP "logicapp.zip"
    Compress-Archive -Path "$logicAppPath\*" -DestinationPath $zipPath -Force

    az functionapp deployment source config-zip `
        --resource-group $ResourceGroupName `
        --name $deployment.logicAppName.value `
        --src $zipPath

    Remove-Item $zipPath -Force
    Write-Host "Logic App workflow deployed!" -ForegroundColor Green
}

# Get APIM subscription key
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "APIM Subscription Key" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$subscriptionKey = az apim subscription show `
    --resource-group $ResourceGroupName `
    --service-name $deployment.apimName.value `
    --subscription-id "demo-subscription" `
    --query "primaryKey" -o tsv 2>$null

if ($subscriptionKey) {
    Write-Host "Subscription Key: $subscriptionKey" -ForegroundColor Yellow
} else {
    Write-Host "Note: APIM may still be provisioning. Key will be available soon." -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Deploy Function App code: -DeployFunctionCode"
Write-Host "  2. Deploy Logic App workflow: -DeployLogicAppWorkflow"
Write-Host "  3. Configure APIM backend URL to Logic App callback"
Write-Host "  4. Test the API endpoint"
Write-Host ""
Write-Host "Test Command:" -ForegroundColor Yellow
Write-Host @"

curl -X POST '$($deployment.apiEndpoint.value)' \
  -H 'Content-Type: application/json' \
  -H 'Ocp-Apim-Subscription-Key: <subscription-key>' \
  -d '{
    "deviceId": "test-device",
    "region": "eastus",
    "timestamp": "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')",
    "telemetryType": "metrics",
    "data": {"cpu": 50, "memory": 75}
  }'
"@
