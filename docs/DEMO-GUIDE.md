# StreamBridge Demo Guide

This guide walks you through deploying and demonstrating the StreamBridge serverless telemetry ingestion pipeline.

**Estimated Time: 20-30 minutes**

---

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Azure CLI | 2.50+ | `winget install Microsoft.AzureCLI` |
| PowerShell | 7+ | `winget install Microsoft.PowerShell` |
| Azure Functions Core Tools | 4.x | `npm install -g azure-functions-core-tools@4` |

### Azure Requirements

- Active Azure subscription
- Owner or Contributor role on subscription
- Available quota in `eastus2` region for:
  - Cosmos DB (Serverless)
  - Function App (Consumption)
  - Logic Apps (Standard)
  - API Management (Consumption)

---

## Part 1: Infrastructure Deployment (15 minutes)

### Step 1.1: Clone and Navigate

```powershell
cd c:\Users\segayle\repos\streambridge
```

### Step 1.2: Login to Azure

```powershell
az login
az account show  # Verify correct subscription
```

### Step 1.3: Deploy Infrastructure

```powershell
# Option A: Using deployment script
.\scripts\deploy.ps1 -ResourceGroupName "rg-streambridge" -Location "eastus2"

# Option B: Manual Bicep deployment
az group create --name rg-streambridge --location eastus2
az deployment group create `
    --resource-group rg-streambridge `
    --template-file infrastructure/main.bicep `
    --parameters location=eastus2 environment=dev
```

### Step 1.4: Capture Deployment Outputs

After deployment, note these values:

```powershell
# Get deployment outputs
az deployment group show `
    --resource-group rg-streambridge `
    --name main `
    --query "properties.outputs" -o table
```

**Save these values:**
- `cosmosAccountName`: _______________
- `functionAppName`: _______________
- `logicAppName`: _______________
- `apimName`: _______________
- `apiEndpoint`: _______________

---

## Part 2: Deploy Application Code (5 minutes)

### Step 2.1: Deploy Function App

```powershell
cd function-app

# Create virtual environment (optional, for local testing)
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Deploy to Azure
func azure functionapp publish <functionAppName> --python

cd ..
```

### Step 2.2: Deploy Logic App Workflow

The Logic App workflow is deployed via Azure Portal or CLI:

```powershell
# Zip the logic app files
Compress-Archive -Path "logic-app\*" -DestinationPath "logicapp.zip" -Force

# Deploy
az functionapp deployment source config-zip `
    --resource-group rg-streambridge `
    --name <logicAppName> `
    --src logicapp.zip

Remove-Item logicapp.zip
```

---

## Part 3: Configure APIM (5 minutes)

### Step 3.1: Get Logic App Callback URL

```powershell
# In Azure Portal:
# 1. Go to Logic App → Workflows → TelemetryIngestion
# 2. Click "Workflow URL" and copy the URL

# Or via CLI (after workflow is created)
az rest --method post `
    --uri "https://management.azure.com/subscriptions/{sub}/resourceGroups/rg-streambridge/providers/Microsoft.Web/sites/<logicAppName>/hostruntime/runtime/webhooks/workflow/api/management/workflows/TelemetryIngestion/triggers/manual/listCallbackUrl?api-version=2022-03-01" `
    --query "value" -o tsv
```

### Step 3.2: Update APIM Backend

```powershell
# Set the Logic App URL as a named value in APIM
az apim nv create `
    --resource-group rg-streambridge `
    --service-name <apimName> `
    --named-value-id LogicAppCallbackUrl `
    --display-name "Logic App Callback URL" `
    --value "<logic-app-callback-url>"
```

### Step 3.3: Get Subscription Key

```powershell
$subscriptionKey = az apim subscription show `
    --resource-group rg-streambridge `
    --service-name <apimName> `
    --subscription-id demo-subscription `
    --query "primaryKey" -o tsv

Write-Host "Subscription Key: $subscriptionKey"
```

---

## Part 4: Demo Scenarios

### Scenario 1: Basic Telemetry Ingestion

```powershell
$headers = @{
    "Content-Type" = "application/json"
    "Ocp-Apim-Subscription-Key" = "<subscription-key>"
}

$body = @{
    deviceId = "demo-device-001"
    region = "eastus"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    telemetryType = "metrics"
    data = @{
        cpu = 42.5
        memory = 68.3
        diskUsage = 55.0
        networkIn = 1024
        networkOut = 512
    }
} | ConvertTo-Json

$response = Invoke-RestMethod `
    -Uri "https://<apimName>.azure-api.net/telemetry/uploadTelemetry" `
    -Method POST `
    -Headers $headers `
    -Body $body

$response | ConvertTo-Json -Depth 5
```

**Expected Result:**
- Status 200
- `documentId` returned
- `processingResult.status` = "stored"

### Scenario 2: Crash Dump Processing

```powershell
$crashBody = @{
    deviceId = "demo-device-002"
    region = "westus2"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    telemetryType = "crashDump"
    data = @{
        lastKnownState = "running"
        uptime = 3600
    }
    crashDump = @{
        dumpId = "crash-" + [guid]::NewGuid().ToString().Substring(0,8)
        errorCode = "0xC0000005"
        stackTrace = "ntdll.dll!RtlUserThreadStart`nkernel32.dll!BaseThreadInitThunk`nmyapp.exe!main"
        processName = "myapp.exe"
        memoryDumpUrl = "https://storage.blob.core.windows.net/dumps/crash.dmp"
    }
} | ConvertTo-Json -Depth 5

$response = Invoke-RestMethod `
    -Uri "https://<apimName>.azure-api.net/telemetry/uploadTelemetry" `
    -Method POST `
    -Headers $headers `
    -Body $crashBody

$response | ConvertTo-Json -Depth 10
```

**Expected Result:**
- Status 200
- `processingResult.status` = "processed"
- `processingResult.functionResponse` contains crash analysis

### Scenario 3: Rate Limiting Demo

```powershell
# Send 110 requests quickly to trigger rate limiting
1..110 | ForEach-Object {
    try {
        $result = Invoke-RestMethod `
            -Uri "https://<apimName>.azure-api.net/telemetry/uploadTelemetry" `
            -Method POST `
            -Headers $headers `
            -Body $body
        Write-Host "Request $_: Success"
    }
    catch {
        Write-Host "Request $_: Rate Limited - $($_.Exception.Response.StatusCode)"
    }
}
```

**Expected Result:**
- First 100 requests succeed
- Remaining requests return 429

### Scenario 4: Invalid Payload

```powershell
$invalidBody = @{
    invalidField = "test"
} | ConvertTo-Json

try {
    Invoke-RestMethod `
        -Uri "https://<apimName>.azure-api.net/telemetry/uploadTelemetry" `
        -Method POST `
        -Headers $headers `
        -Body $invalidBody
}
catch {
    Write-Host "Status: $($_.Exception.Response.StatusCode)"
    $_.ErrorDetails.Message
}
```

**Expected Result:**
- Status 400
- Error message about missing required fields

---

## Part 5: Verification in Azure Portal

### 5.1: Check Cosmos DB Data

1. Navigate to **Azure Portal** → **rg-streambridge** → **Cosmos DB Account**
2. Open **Data Explorer**
3. Expand **StreamBridgeDemo** → **TelemetryData**
4. Click **Items** to see stored documents
5. Verify documents contain:
   - `deviceId`, `region`, `timestamp`
   - `processingResult` with status
   - `ingestedAt` timestamp

### 5.2: Check Logic App Run History

1. Navigate to **Logic App** → **Workflows** → **TelemetryIngestion**
2. Click **Run history**
3. Click on a run to see:
   - Trigger input/output
   - Each action's execution
   - Duration and status

### 5.3: Check Function App Invocations

1. Navigate to **Function App** → **Functions** → **ProcessCrashDump**
2. Click **Monitor**
3. View:
   - Invocation logs
   - Success/failure counts
   - Duration metrics

### 5.4: Check APIM Analytics

1. Navigate to **API Management** → **Analytics**
2. View:
   - Request count
   - Response times
   - Error rates
   - Geographic distribution

---

## Part 6: Cleanup

```powershell
# Delete all resources
az group delete --name rg-streambridge --yes --no-wait

# Verify deletion
az group show --name rg-streambridge 2>&1
# Should return "Resource group not found"
```

---

## Troubleshooting

### Issue: APIM returns 500 error

**Cause:** Logic App callback URL not configured

**Solution:**
1. Get Logic App workflow URL from Azure Portal
2. Update APIM named value `LogicAppCallbackUrl`
3. Verify APIM policy references the named value

### Issue: Function App not responding

**Cause:** Code not deployed or cold start

**Solution:**
1. Check Function App is running: `az functionapp show --name <name> --query state`
2. Redeploy code: `func azure functionapp publish <name>`
3. Wait for cold start (first request may take 10-20 seconds)

### Issue: Cosmos DB permission denied

**Cause:** Managed identity role not assigned

**Solution:**
```powershell
# Assign Cosmos DB Data Contributor role
$logicAppPrincipalId = az webapp identity show `
    --name <logicAppName> `
    --resource-group rg-streambridge `
    --query principalId -o tsv

az cosmosdb sql role assignment create `
    --account-name <cosmosAccountName> `
    --resource-group rg-streambridge `
    --role-definition-id 00000000-0000-0000-0000-000000000002 `
    --principal-id $logicAppPrincipalId `
    --scope "/"
```

### Issue: Rate limit hit during demo

**Solution:**
- Wait 60 seconds for rate limit window to reset
- Or use a different subscription key

---

## Demo Talking Points

### Architecture Benefits

1. **Serverless & Cost-Effective**
   - Pay only for what you use
   - Auto-scales to zero when idle
   - No infrastructure management

2. **Security**
   - API key authentication at APIM
   - Managed identity (no credentials in code)
   - TLS encryption everywhere

3. **Observability**
   - Built-in monitoring with App Insights
   - Logic Apps visual run history
   - Cosmos DB query metrics

4. **Scalability**
   - APIM handles millions of requests
   - Cosmos DB auto-partitions by region
   - Functions scale to demand

### Use Cases

- IoT telemetry ingestion
- Application crash reporting
- Event streaming pipelines
- Log aggregation systems

---

## Next Steps

- Add more telemetry types
- Integrate with Power BI for dashboards
- Add alerts for crash patterns
- Implement data retention policies
