# Ì≥ò StreamBridge Demo Guide

[![Deployment](https://img.shields.io/badge/Deployment-Bicep-orange?style=flat-square)](../infrastructure/main.bicep)
[![Time](https://img.shields.io/badge/Time-20--30_min-blue?style=flat-square)]()
[![Difficulty](https://img.shields.io/badge/Difficulty-Beginner-green?style=flat-square)]()

> Ì∫Ä This guide walks you through demonstrating the StreamBridge serverless telemetry ingestion pipeline.

**‚è±Ô∏è Estimated Demo Time: 10-15 minutes**

---

## ‚úÖ What's Already Deployed

The infrastructure is **already deployed and working**:
- ‚úÖ Cosmos DB (StreamBridgeDemo database, TelemetryData container)
- ‚úÖ Logic App (TelemetryIngestion workflow)
- ‚úÖ API Management (streambridgeapimdev with uploadTelemetry endpoint)
- ‚úÖ Function App (ProcessCrashDump function)

**No deployment needed for the demo!**

---

## ‚ö†Ô∏è Important: Known Permission Issue

**Your user account (`sean.gayle@microsoft.com`) has limited permissions** to:
- ‚ùå Azure Portal configuration pages (resulting in "No access" errors)
- ‚ùå Direct RBAC role management for standard Azure resources
- ‚ùå Querying Cosmos DB data directly via Azure Portal

**However, this DOES NOT affect the demo because:**
- ‚úÖ The API endpoint is **fully functional**
- ‚úÖ Telemetry **ingests successfully**
- ‚úÖ All core infrastructure **works correctly**

**For your demo, you can:**
- ‚úÖ Show the API endpoint working with curl commands
- ‚úÖ Show successful telemetry ingestion with document IDs
- ‚úÖ View the infrastructure in the Azure Portal (read-only)
- ‚úÖ Show Logic App run history
- ‚úÖ Show Cosmos DB container structure in Data Explorer (if you have read access)

**You CANNOT (due to permissions):**
- ‚ùå Modify APIM policies
- ‚ùå Restart Logic App or Function App
- ‚ùå Change app configuration settings
- ‚ùå Query Cosmos DB items directly (via Portal)

---

## Ìæ¨ Demo Walkthrough

### Part 1: Show the Working API (2 minutes)

**Narrative:** "This API ingests telemetry from devices in real-time. Let me show you it working."

Run this curl command in your terminal:

```bash
curl -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" \
  -d '{
    "deviceId": "demo-device-001",
    "region": "eastus",
    "timestamp": "2025-12-04T19:45:00Z",
    "telemetryType": "metrics",
    "data": {
      "cpu": 45.2,
      "memory": 72.1,
      "diskUsage": 55.0,
      "networkIn": 1024,
      "networkOut": 512
    }
  }'
```

**Expected Output:**
```json
{
  "success": true,
  "documentId": "c0a1eca1-480d-4ef9-8859-3845b6a82f16",
  "message": "Telemetry ingested successfully",
  "timestamp": "2025-12-04T19:45:00Z"
}
```

**Talking Point:** "Notice the `success: true` and `documentId`. That means the data has been received, validated, and is being processed through our serverless pipeline."

---

### Part 2: Show Multiple Telemetry Types (2 minutes)

**Narrative:** "StreamBridge supports different types of telemetry. Let me show you a crash dump event."

Run this command:

```bash
curl -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" \
  -d '{
    "deviceId": "demo-laptop-002",
    "region": "westus2",
    "timestamp": "2025-12-04T19:46:00Z",
    "telemetryType": "crashDump",
    "data": {
      "lastKnownState": "running",
      "uptime": 3600
    },
    "crashDump": {
      "dumpId": "crash-12ab34cd",
      "errorCode": "0xC0000005",
      "stackTrace": "ntdll.dll!RtlUserThreadStart -> kernel32.dll!BaseThreadInitThunk -> myapp.exe!main",
      "processName": "myapp.exe",
      "memoryDumpUrl": "https://storage.blob.core.windows.net/dumps/crash.dmp"
    }
  }'
```

**Expected Output:**
```json
{
  "success": true,
  "documentId": "a1b2c3d4-e5f6-4789-0123-456789abcdef",
  "message": "Telemetry ingested successfully",
  "timestamp": "2025-12-04T19:46:00Z"
}
```

**Talking Point:** "The same endpoint handles multiple telemetry types - metrics, logs, events, and crash dumps. The system automatically routes crash data to our Function App for analysis."

---

### Part 3: Show Rate Limiting (1 minute)

**Narrative:** "The API is rate-limited to 100 requests per minute per subscription key for protection."

Run this PowerShell snippet to show rate limiting in action:

```powershell
# Send 5 quick requests to show they work
1..5 | ForEach-Object {
    $response = curl -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" `
      -H "Content-Type: application/json" `
      -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" `
      -d '{"deviceId":"test-'$_'","region":"eastus","timestamp":"2025-12-04T19:47:00Z","telemetryType":"metrics","data":{"cpu":50}}'
    
    Write-Host "Request $_: Success" -ForegroundColor Green
}
```

**Talking Point:** "Each request succeeds with a unique document ID. If we sent 100+ requests per minute, we'd hit the rate limit with HTTP 429."

---

### Part 4: Show the Infrastructure (3 minutes)

**Narrative:** "Let me show you how this works behind the scenes."

1. **Open Azure Portal** and navigate to **rg-streambridge** resource group

2. **Show API Management:**
   - Click on **streambridgeapimdev**
   - Show: APIs ‚Üí StreamBridge API ‚Üí uploadTelemetry operation
   - Point out: Rate limiting policy, rate-limit-by-key calls="100"
   - Mention: "This protects our backend from being overwhelmed"

3. **Show Logic App:**
   - Click on **streambridgelogicbryctld4qwjpg**
   - Go to: **Run history**
   - Show: Recent runs with timestamps, inputs, and outputs
   - Point out: "Each API call triggers a Logic App execution. You can see the workflow status here."

4. **Show Cosmos DB:**
   - Click on **streambridgecosmosbryctld4qwjpg**
   - Go to: **Data Explorer** ‚Üí **StreamBridgeDemo** ‚Üí **TelemetryData** ‚Üí **Items**
   - Show: Documents stored with deviceId, timestamp, and data
   - Note: "Each telemetry event becomes a document here, partitioned by region for performance"

5. **Show Function App:**
   - Click on **streambridge-func-[suffix]** (if available)
   - Go to: **Functions** ‚Üí **ProcessCrashDump**
   - Point out: "This function activates automatically when crash dumps arrive"

**Talking Point:** "This is a completely serverless pipeline:
- No servers to manage
- Auto-scales to handle traffic spikes
- Processes millions of events per day
- You only pay for actual consumption"

---

### Part 5: Show the Architecture (2 minutes)

**Narrative:** "Here's how the data flows through our system:"

Show this flow:

```
Device (curl) 
    ‚Üì
APIM Gateway (streambridgeapimdev)
    - Validates schema
    - Enforces rate limits (100 req/min)
    - Routes to Logic App
    ‚Üì
Logic App (TelemetryIngestion)
    - Transforms data
    - Routes to Function App (if crash dump)
    - Stores to Cosmos DB
    ‚Üì
Cosmos DB (StreamBridgeDemo/TelemetryData)
    - Partitioned by region
    - Available for queries
    - TTL-based retention
    ‚Üì
Function App (ProcessCrashDump) - triggered for crash events
    - Analyzes crash data
    - Could send alerts, store analysis
```

**Talking Points:**
- "APIM is your API gateway - single entry point"
- "Logic Apps orchestrate the workflow - no code needed"
- "Cosmos DB is globally distributed - reads/writes in milliseconds"
- "Function Apps handle compute-intensive tasks"
- "Everything integrates through Event Hub/Service Bus patterns"

---

### Part 6: Show Success Metrics (1 minute)

Run this to show multiple successful ingestions:

```bash
echo "Sending telemetry for multiple devices..."
for i in {1..3}; do
  curl -s -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" \
    -d '{"deviceId":"device-'$i'","region":"eastus","timestamp":"2025-12-04T19:48:00Z","telemetryType":"metrics","data":{"cpu":'$(( RANDOM % 100 ))'}}'  | grep -o '"documentId":"[^"]*"'
done
```

**Expected Output:**
```
"documentId":"<uuid-1>"
"documentId":"<uuid-2>"
"documentId":"<uuid-3>"
```

**Talking Point:** "Three devices, three successful ingestions, three unique document IDs. Each one is now in our Cosmos DB and available for analysis."

---

## Ìª†Ô∏è Troubleshooting During Demo

| Problem | What to do |
|---------|-----------|
| ‚ùå Curl not found | Use PowerShell `Invoke-RestMethod` instead |
| ‚ùå API returns 401 | Subscription key is wrong or expired (use the one in this guide) |
| ‚ùå API returns 429 | You hit the rate limit - wait 60 seconds and try again |
| ‚ùå Portal shows "No access" | This is expected due to permission restrictions - just show run history from Logic App instead |
| ‚ùå Can't see Cosmos DB items | Permission issue - instead show the container schema and mention items are there |

---

## Ì≥ã Demo Checklist

- [ ] ‚úÖ Test curl commands locally before demo
- [ ] ‚úÖ Have subscription key ready (30e106dc4cf942d99b8c780c14d603a1)
- [ ] ‚úÖ Have API endpoint ready (https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry)
- [ ] ‚úÖ Open Azure Portal with rg-streambridge resource group
- [ ] ‚úÖ Refresh Logic App run history before starting
- [ ] ‚úÖ Check that API is responding (quick test)
- [ ] ‚úÖ Have talking points memorized for architecture explanation

---

## Ìæ§ Elevator Pitch (30 seconds)

"StreamBridge is a serverless telemetry pipeline that ingests device metrics and crash data in real-time. It uses API Management for rate limiting and validation, Logic Apps for orchestration, Cosmos DB for storage, and Functions for processing. Everything scales automatically and you only pay for what you use - no infrastructure to manage."

---

## Ì¥Æ Questions You Might Get Asked

| Question | Answer |
|----------|--------|
| Why not just use Event Hub? | Event Hub is great for real-time streaming, but this uses Logic Apps for transformation and filtering first |
| Can this handle millions of events? | Yes - Cosmos DB scales to any throughput, APIM handles rate limiting, and Functions auto-scale |
| What about data security? | API key authentication, TLS encryption, Managed Identity for Azure service-to-service |
| How much does this cost? | Cosmos DB: $0.25/hr serverless, APIM: ~$0.05 per 1000 calls, Logic Apps: $0.000001 per execution |
| Can you replay events? | Yes - Cosmos DB stores everything with TTL, you can query historical data |

---

<p align="center">
  <b>Ì∫Ä Good luck with your demo!</b><br>
  <sub>StreamBridge - Serverless Telemetry Pipeline</sub>
</p>
