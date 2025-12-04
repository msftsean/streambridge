# 🎯 StreamBridge Demo Walkthrough

> A step-by-step guide to demonstrate all features of the StreamBridge telemetry ingestion pipeline.

---

## 📋 Demo Prerequisites

Before starting the demo, ensure you have:

| Requirement | Status |
|-------------|--------|
| ✅ Azure resources deployed in `rg-streambridge` | Required |
| ✅ APIM subscription key available | Required |
| ✅ PowerShell 7+ or terminal with curl | Required |
| ✅ Azure Portal access | Recommended |

### 🔑 Your Demo Credentials

```
APIM Gateway:     https://streambridgeapimdev.azure-api.net
API Endpoint:     https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry
Subscription Key: 30e106dc4cf942d99b8c780c14d603a1
```

---

## 🎬 Demo Scenarios

### Scenario 1: Basic Telemetry Ingestion 📊

**Purpose:** Show the happy path of sending device telemetry through the pipeline.

#### Step 1.1: Send Metrics Telemetry

```powershell
$headers = @{
    "Content-Type" = "application/json"
    "Ocp-Apim-Subscription-Key" = "30e106dc4cf942d99b8c780c14d603a1"
}

$body = @{
    deviceId = "demo-laptop-001"
    region = "eastus"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    telemetryType = "metrics"
    data = @{
        cpu = 45.2
        memory = 72.1
        diskUsage = 55.0
        networkIn = 1024
        networkOut = 512
    }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
    -Uri "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" `
    -Method POST `
    -Headers $headers `
    -Body $body
```

#### ✅ Expected Result:
```json
{
  "success": true,
  "documentId": "<guid>",
  "message": "Telemetry stored successfully",
  "processingResult": { "status": "stored" }
}
```

#### 💬 Talking Points:
- "Notice the request goes through API Management first for authentication"
- "The Logic App validates the payload and routes to Cosmos DB"
- "Response includes the document ID for traceability"

---

### Scenario 2: Crash Dump Processing 💥

**Purpose:** Demonstrate the Function App processing crash dump metadata.

#### Step 2.1: Send Crash Dump Telemetry

```powershell
$crashBody = @{
    deviceId = "production-server-042"
    region = "westus2"
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    telemetryType = "crashDump"
    data = @{
        lastKnownState = "running"
        uptime = 86400
    }
    crashDump = @{
        dumpId = "crash-" + [guid]::NewGuid().ToString().Substring(0,8)
        errorCode = "0xC0000005"
        stackTrace = "ntdll.dll!RtlUserThreadStart`nkernel32.dll!BaseThreadInitThunk`nmyapp.exe!ProcessData`nmyapp.exe!main"
        processName = "myapp.exe"
        memoryDumpUrl = "https://storage.blob.core.windows.net/dumps/crash.dmp"
    }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod `
    -Uri "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" `
    -Method POST `
    -Headers $headers `
    -Body $crashBody
```

#### ✅ Expected Result:
```json
{
  "success": true,
  "documentId": "<guid>",
  "message": "Telemetry stored successfully",
  "processingResult": {
    "status": "processed",
    "crashAnalysis": {
      "severity": "critical",
      "category": "Access Violation"
    }
  }
}
```

#### 💬 Talking Points:
- "When crashDump is present, Logic App routes to the Function App"
- "The Function App analyzes the error code and stack trace"
- "Results are stored in Cosmos DB with the analysis"

---

### Scenario 3: Multi-Region Telemetry 🌍

**Purpose:** Show partition key effectiveness with multiple regions.

#### Step 3.1: Send Data from Multiple Regions

```powershell
$regions = @("eastus", "westus2", "centralus", "northeurope", "westeurope")

foreach ($region in $regions) {
    $body = @{
        deviceId = "global-sensor-" + $region
        region = $region
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        telemetryType = "metrics"
        data = @{
            temperature = Get-Random -Minimum 20 -Maximum 35
            humidity = Get-Random -Minimum 40 -Maximum 80
        }
    } | ConvertTo-Json

    $result = Invoke-RestMethod `
        -Uri "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" `
        -Method POST `
        -Headers $headers `
        -Body $body

    Write-Host "✅ $region : $($result.documentId)"
}
```

#### 💬 Talking Points:
- "Data is partitioned by region for optimal query performance"
- "Each region gets its own logical partition in Cosmos DB"
- "Queries within a region are fast and cost-effective"

---

### Scenario 4: Rate Limiting Demo 🚦

**Purpose:** Demonstrate API protection with rate limiting.

#### Step 4.1: Trigger Rate Limit (100 requests/minute)

```powershell
Write-Host "📊 Sending 110 requests to trigger rate limiting..."
$success = 0
$rateLimited = 0

1..110 | ForEach-Object {
    try {
        $body = @{
            deviceId = "rate-test"
            region = "eastus"
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            telemetryType = "metrics"
            data = @{ requestNumber = $_ }
        } | ConvertTo-Json

        $null = Invoke-RestMethod `
            -Uri "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" `
            -Method POST `
            -Headers $headers `
            -Body $body

        $success++
        Write-Host "." -NoNewline -ForegroundColor Green
    }
    catch {
        $rateLimited++
        if ($rateLimited -eq 1) {
            Write-Host "`n🚫 Rate limit hit at request $_" -ForegroundColor Yellow
        }
        Write-Host "x" -NoNewline -ForegroundColor Red
    }
}

Write-Host "`n`n📈 Results: $success succeeded, $rateLimited rate-limited"
```

#### ✅ Expected Result:
- First ~100 requests succeed
- Remaining requests return HTTP 429
- `Retry-After` header indicates wait time

#### 💬 Talking Points:
- "Rate limiting protects backend services from abuse"
- "100 requests per minute per subscription key"
- "Clients receive Retry-After header for graceful retry"

---

### Scenario 5: Invalid Payload Validation ❌

**Purpose:** Demonstrate payload validation at the API level.

#### Step 5.1: Send Invalid Payload

```powershell
$invalidBody = @{
    invalidField = "test"
} | ConvertTo-Json

try {
    Invoke-RestMethod `
        -Uri "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" `
        -Method POST `
        -Headers $headers `
        -Body $invalidBody
}
catch {
    Write-Host "❌ Expected Error:" -ForegroundColor Yellow
    Write-Host $_.ErrorDetails.Message
    Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)"
}
```

#### ✅ Expected Result:
- HTTP 400 Bad Request
- Error message about missing required fields

#### 💬 Talking Points:
- "Schema validation happens at the API level"
- "Invalid requests never reach backend services"
- "Clear error messages help developers fix issues"

---

## 🔍 Verification in Azure Portal

### Step 6: View Data in Cosmos DB

1. **Navigate to Azure Portal** → `rg-streambridge` → `Cosmos DB Account`
2. Open **Data Explorer**
3. Expand **StreamBridgeDemo** → **TelemetryData**
4. Click **Items** to see stored documents

**Query to run:**
```sql
SELECT c.deviceId, c.region, c.telemetryType, c.timestamp
FROM c
ORDER BY c._ts DESC
```

### Step 7: View Logic App Run History

1. **Navigate to** → `rg-streambridge` → `Logic App`
2. Click **Workflows** → **TelemetryIngestion**
3. Click **Run history**
4. Click a run to see:
   - ✅ Trigger input/output
   - ✅ Each action's execution
   - ✅ Duration and status

### Step 8: Check APIM Analytics

1. **Navigate to** → `rg-streambridge` → `API Management`
2. Click **Analytics**
3. View:
   - 📊 Request count
   - ⏱️ Response times
   - ❌ Error rates

---

## 🔗 Graph Analytics Demo

### Step 9: Run Gremlin Queries

1. **Navigate to** → `streambridgegraphdb` → **Data Explorer**
2. Expand **StreamBridgeGraph** → **TelemetryGraph**
3. Click **New Query**

**Demo Queries:**

```gremlin
// Count all vertices
g.V().count()

// Group by label
g.V().groupCount().by(label)

// Find all devices
g.V().hasLabel('device').values('deviceId')
```

---

## 📊 Demo Summary Slide

| Feature | Demonstrated | Status |
|---------|--------------|--------|
| 🔐 API Authentication | APIM subscription key | ✅ |
| 📊 Telemetry Ingestion | Metrics data flow | ✅ |
| 💥 Crash Processing | Function App analysis | ✅ |
| 🌍 Multi-Region | Partition key usage | ✅ |
| 🚦 Rate Limiting | 100 req/min protection | ✅ |
| ❌ Validation | Schema enforcement | ✅ |
| 🔗 Graph Analytics | Gremlin queries | ✅ |

---

## 🎤 Key Talking Points

### Architecture Benefits

1. **🚀 Serverless & Cost-Effective**
   - Pay only for what you use
   - Auto-scales to zero when idle
   - No infrastructure management

2. **🔒 Security**
   - API key authentication at APIM
   - Managed identity (no credentials in code)
   - TLS encryption everywhere

3. **📊 Observability**
   - Built-in monitoring with App Insights
   - Logic Apps visual run history
   - Cosmos DB query metrics

4. **📈 Scalability**
   - APIM handles millions of requests
   - Cosmos DB auto-partitions by region
   - Functions scale to demand

---

## 🧹 Cleanup After Demo

```powershell
# Delete all resources (if needed)
az group delete --name rg-streambridge --yes --no-wait
```

---

<p align="center">
  <b>🎉 Demo Complete!</b><br>
  <sub>StreamBridge - Serverless Telemetry Pipeline</sub>
</p>
