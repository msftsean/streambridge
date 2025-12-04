# 📘 StreamBridge Demo Guide

[![Deployment](https://img.shields.io/badge/Deployment-Bicep-orange?style=flat-square)](../infrastructure/main.bicep)
[![Time](https://img.shields.io/badge/Time-20--30_min-blue?style=flat-square)]()
[![Difficulty](https://img.shields.io/badge/Difficulty-Beginner-green?style=flat-square)]()

> 🚀 This guide walks you through deploying and demonstrating the StreamBridge serverless telemetry ingestion pipeline.

**⏱️ Estimated Time: 20-30 minutes**

---

## 📋 Prerequisites

### 🛠️ Required Tools

| Tool | Version | Installation | Status |
|------|---------|--------------|--------|
| ![Azure CLI](https://img.shields.io/badge/Azure_CLI-2.50+-0078D4?style=flat-square&logo=microsoftazure) | 2.50+ | `winget install Microsoft.AzureCLI` | ![Required](https://img.shields.io/badge/-Required-red) |
| ![PowerShell](https://img.shields.io/badge/PowerShell-7+-5391FE?style=flat-square&logo=powershell&logoColor=white) | 7+ | `winget install Microsoft.PowerShell` | ![Required](https://img.shields.io/badge/-Required-red) |
| ![Azure Functions](https://img.shields.io/badge/Functions_Tools-4.x-yellow?style=flat-square) | 4.x | `npm install -g azure-functions-core-tools@4` | ![Optional](https://img.shields.io/badge/-Optional-yellow) |

### ☁️ Azure Requirements

| Requirement | Description |
|-------------|-------------|
| 🔑 Active Azure subscription | Valid subscription with billing |
| 👤 Role | Owner or Contributor on subscription |
| 🌍 Region quota | `eastus2` for all resources |

**Resources needed:**
- 📄 Cosmos DB (Serverless)
- 🐍 Function App (Consumption)
- ⚡ Logic Apps (Consumption)
- 🔐 API Management (Developer)

---

## 🏗️ Part 1: Infrastructure Deployment

**⏱️ Time: ~15 minutes**

### Step 1.1: Clone and Navigate 📁

```powershell
cd c:\Users\segayle\repos\streambridge
```

### Step 1.2: Login to Azure 🔐

```powershell
# Login to Azure
az login

# Verify correct subscription
az account show
```

✅ **Expected:** Your subscription name and ID displayed

### Step 1.3: Deploy Infrastructure 🚀

<details>
<summary>📌 Option A: Using Deployment Script (Recommended)</summary>

```powershell
.\scripts\deploy.ps1 -ResourceGroupName "rg-streambridge" -Location "eastus2"
```
</details>

<details>
<summary>📌 Option B: Manual Bicep Deployment</summary>

```powershell
# Create resource group
az group create --name rg-streambridge --location eastus2

# Deploy Bicep template
az deployment group create `
    --resource-group rg-streambridge `
    --template-file infrastructure/main.bicep `
    --parameters location=eastus2 environment=dev
```
</details>

### Step 1.4: Capture Deployment Outputs 📝

After deployment, note these values:

```powershell
# Get deployment outputs
az deployment group show `
    --resource-group rg-streambridge `
    --name main `
    --query "properties.outputs" -o table
```

**📋 Save These Values:**

| Output | Your Value |
|--------|------------|
| 📄 `cosmosAccountName` | _______________ |
| 🐍 `functionAppName` | _______________ |
| ⚡ `logicAppName` | _______________ |
| 🔐 `apimName` | _______________ |
| 🌐 `apiEndpoint` | _______________ |

---

## 🐍 Part 2: Deploy Application Code

**⏱️ Time: ~5 minutes**

### Step 2.1: Deploy Function App

```powershell
cd function-app

# 📦 Create virtual environment (optional, for local testing)
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# 🚀 Deploy to Azure
func azure functionapp publish <functionAppName> --python

cd ..
```

✅ **Expected:** "Deployment successful" message

### Step 2.2: Deploy Logic App Workflow ⚡

```powershell
# 📦 Zip the logic app files
Compress-Archive -Path "logic-app\*" -DestinationPath "logicapp.zip" -Force

# 🚀 Deploy
az functionapp deployment source config-zip `
    --resource-group rg-streambridge `
    --name <logicAppName> `
    --src logicapp.zip

# 🧹 Cleanup
Remove-Item logicapp.zip
```

---

## 🔐 Part 3: Configure APIM

**⏱️ Time: ~5 minutes**

### Step 3.1: Get Logic App Callback URL 🔗

<details>
<summary>🖥️ Via Azure Portal</summary>

1. Go to **Logic App** → **Workflows** → **TelemetryIngestion**
2. Click **"Workflow URL"** and copy the URL
</details>

<details>
<summary>💻 Via CLI</summary>

```powershell
az rest --method post `
    --uri "https://management.azure.com/subscriptions/{sub}/resourceGroups/rg-streambridge/providers/Microsoft.Web/sites/<logicAppName>/hostruntime/runtime/webhooks/workflow/api/management/workflows/TelemetryIngestion/triggers/manual/listCallbackUrl?api-version=2022-03-01" `
    --query "value" -o tsv
```
</details>

### Step 3.2: Update APIM Backend 🔧

```powershell
# Set the Logic App URL as a named value in APIM
az apim nv create `
    --resource-group rg-streambridge `
    --service-name <apimName> `
    --named-value-id LogicAppCallbackUrl `
    --display-name "Logic App Callback URL" `
    --value "<logic-app-callback-url>"
```

### Step 3.3: Get Subscription Key 🔑

```powershell
$subscriptionKey = az apim subscription show `
    --resource-group rg-streambridge `
    --service-name <apimName> `
    --subscription-id demo-subscription `
    --query "primaryKey" -o tsv

Write-Host "🔑 Subscription Key: $subscriptionKey"
```

---

## 🎬 Part 4: Demo Scenarios

### Scenario 1: Basic Telemetry Ingestion 📊

![Status](https://img.shields.io/badge/Scenario-Telemetry-blue?style=flat-square)

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

**✅ Expected Result:**
| Field | Value |
|-------|-------|
| Status | `200` |
| `documentId` | `<guid>` |
| `processingResult.status` | `"stored"` |

---

### Scenario 2: Crash Dump Processing 💥

![Status](https://img.shields.io/badge/Scenario-Crash_Dump-red?style=flat-square)

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

**✅ Expected Result:**
| Field | Value |
|-------|-------|
| Status | `200` |
| `processingResult.status` | `"processed"` |
| `processingResult.functionResponse` | Contains crash analysis |

---

### Scenario 3: Rate Limiting Demo 🚦

![Status](https://img.shields.io/badge/Scenario-Rate_Limit-orange?style=flat-square)

```powershell
# 📊 Send 110 requests quickly to trigger rate limiting
1..110 | ForEach-Object {
    try {
        $result = Invoke-RestMethod `
            -Uri "https://<apimName>.azure-api.net/telemetry/uploadTelemetry" `
            -Method POST `
            -Headers $headers `
            -Body $body
        Write-Host "✅ Request $_: Success" -ForegroundColor Green
    }
    catch {
        Write-Host "🚫 Request $_: Rate Limited - $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}
```

**✅ Expected Result:**
| Requests | Result |
|----------|--------|
| 1-100 | ✅ Success |
| 101-110 | 🚫 HTTP 429 |

---

### Scenario 4: Invalid Payload ❌

![Status](https://img.shields.io/badge/Scenario-Validation-yellow?style=flat-square)

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
    Write-Host "❌ Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    $_.ErrorDetails.Message
}
```

**✅ Expected Result:**
| Field | Value |
|-------|-------|
| Status | `400 Bad Request` |
| Message | Missing required fields |

---

## 🔍 Part 5: Verification in Azure Portal

### 5.1: Check Cosmos DB Data 📄

1. Navigate to **Azure Portal** → **rg-streambridge** → **Cosmos DB Account**
2. Open **Data Explorer** 📊
3. Expand **StreamBridgeDemo** → **TelemetryData**
4. Click **Items** to see stored documents

**✅ Verify documents contain:**
- ✔️ `deviceId`, `region`, `timestamp`
- ✔️ `processingResult` with status
- ✔️ `ingestedAt` timestamp

### 5.2: Check Logic App Run History ⚡

1. Navigate to **Logic App** → **Workflows** → **TelemetryIngestion**
2. Click **Run history**
3. Click on a run to see:
   - ✅ Trigger input/output
   - ✅ Each action's execution
   - ⏱️ Duration and status

### 5.3: Check Function App Invocations 🐍

1. Navigate to **Function App** → **Functions** → **ProcessCrashDump**
2. Click **Monitor**
3. View:
   - 📋 Invocation logs
   - ✅ Success/failure counts
   - ⏱️ Duration metrics

### 5.4: Check APIM Analytics 🔐

1. Navigate to **API Management** → **Analytics**
2. View:
   - 📊 Request count
   - ⏱️ Response times
   - ❌ Error rates
   - 🌍 Geographic distribution

---

## 🧹 Part 6: Cleanup

```powershell
# 🗑️ Delete all resources
az group delete --name rg-streambridge --yes --no-wait

# ✅ Verify deletion
az group show --name rg-streambridge 2>&1
# Should return "Resource group not found"
```

---

## 🔧 Troubleshooting

### ❌ Issue: APIM returns 500 error

| Cause | Solution |
|-------|----------|
| 🔗 Logic App callback URL not configured | 1. Get Logic App workflow URL from Azure Portal<br>2. Update APIM named value `LogicAppCallbackUrl`<br>3. Verify APIM policy references the named value |

### ❌ Issue: Function App not responding

| Cause | Solution |
|-------|----------|
| 📦 Code not deployed or cold start | 1. Check Function App is running: `az functionapp show --name <name> --query state`<br>2. Redeploy code: `func azure functionapp publish <name>`<br>3. Wait for cold start (10-20 seconds) |

### ❌ Issue: Cosmos DB permission denied

| Cause | Solution |
|-------|----------|
| 🔐 Managed identity role not assigned | Run the commands below |

```powershell
# 🔧 Assign Cosmos DB Data Contributor role
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

### ❌ Issue: Rate limit hit during demo

| Cause | Solution |
|-------|----------|
| 🚦 Exceeded 100 req/min | ⏳ Wait 60 seconds for rate limit window to reset<br>🔑 Or use a different subscription key |

---

## 🎤 Demo Talking Points

### 🏗️ Architecture Benefits

| Benefit | Details |
|---------|---------|
| 🚀 **Serverless & Cost-Effective** | Pay only for what you use • Auto-scales to zero when idle • No infrastructure management |
| 🔒 **Security** | API key authentication at APIM • Managed identity (no credentials in code) • TLS encryption everywhere |
| 📊 **Observability** | Built-in monitoring with App Insights • Logic Apps visual run history • Cosmos DB query metrics |
| 📈 **Scalability** | APIM handles millions of requests • Cosmos DB auto-partitions by region • Functions scale to demand |

### 💡 Use Cases

| Use Case | Icon |
|----------|------|
| IoT telemetry ingestion | 📡 |
| Application crash reporting | 💥 |
| Event streaming pipelines | 🔄 |
| Log aggregation systems | 📋 |

---

## 🔮 Next Steps

| Enhancement | Description |
|-------------|-------------|
| ➕ Add more telemetry types | Support additional event schemas |
| 📊 Integrate with Power BI | Create real-time dashboards |
| 🔔 Add alerts for crash patterns | Automated incident detection |
| 🗑️ Implement data retention policies | TTL-based cleanup |

---

<p align="center">
  <b>📘 Demo Guide Complete!</b><br>
  <sub>StreamBridge - Serverless Telemetry Pipeline</sub>
</p>
