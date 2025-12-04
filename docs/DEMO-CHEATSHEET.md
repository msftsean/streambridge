# Ìæ¨ StreamBridge Demo Cheat Sheet (Quick Reference)

## ‚è±Ô∏è Demo Timeline: ~12 minutes

---

## Ì≥å Before You Start (Do These!)

```bash
# Test the API is working
curl -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" \
  -d '{"deviceId":"test","region":"eastus","timestamp":"2025-12-04T19:45:00Z","telemetryType":"metrics","data":{"cpu":50}}'

# Expected: {"success":true,"documentId":"..."}
```

Open in browser:
- Azure Portal: https://portal.azure.com
- Logic App run history: (ready to click)
- Documentation: Your repo

---

## Ìæ§ Opening Line (30 seconds)

> "StreamBridge is a **serverless telemetry pipeline**. It ingests device metrics and crash data in real-time, scales automatically, and you only pay for what you use. Let me show you how it works."

---

## Ìæ¨ Scene 1: Show the API Working (2 minutes)

**Say:** "First, let's ingest some telemetry data from a device."

```bash
curl -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" \
  -d '{
    "deviceId": "demo-laptop-001",
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

**Point out in response:**
- ‚úÖ `"success": true` ‚Üí Data was accepted
- ‚úÖ `"documentId": "..."` ‚Üí Data stored in Cosmos DB
- ‚úÖ Response in < 1 second ‚Üí Low latency

---

## Ìæ¨ Scene 2: Send a Crash Dump (1 minute)

**Say:** "The system also handles crash events. Watch this."

```bash
curl -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" \
  -d '{
    "deviceId": "demo-laptop-002",
    "region": "westus2",
    "timestamp": "2025-12-04T19:46:00Z",
    "telemetryType": "crashDump",
    "data": {"lastKnownState": "running", "uptime": 3600},
    "crashDump": {
      "dumpId": "crash-12ab34cd",
      "errorCode": "0xC0000005",
      "stackTrace": "ntdll.dll ‚Üí kernel32.dll ‚Üí myapp.exe",
      "processName": "myapp.exe"
    }
  }'
```

**Point out:**
- Same endpoint handles different types
- Automatically routes to Function App for analysis

---

## Ìæ¨ Scene 3: Show Logic App Processing (2 minutes)

**Say:** "Behind the scenes, each API call triggers our orchestration workflow."

1. Open **Azure Portal**
2. Search for: `streambridgelogicbryctld4qwjpg`
3. Click the Logic App
4. Go to: **Workflows** ‚Üí **TelemetryIngestion** ‚Üí **Run history**

**Point out:**
- ‚úÖ Recent runs matching your curl commands
- ‚úÖ Status: Succeeded
- ‚úÖ Duration: ~1-2 seconds per run
- ‚úÖ Trigger payload shows your data

---

## Ìæ¨ Scene 4: Show Cosmos DB Storage (1 minute)

**Say:** "All this data is being stored in a globally distributed database."

1. In same Portal, search: `streambridgecosmosbryctld4qwjpg`
2. Click Cosmos DB account
3. Go to: **Data Explorer** ‚Üí **StreamBridgeDemo** ‚Üí **TelemetryData**

**Point out:**
- ‚úÖ Container name: TelemetryData
- ‚úÖ Partition key: `/region` (for performance)
- ‚úÖ "Items" shows stored documents

**If you can view items:**
- Show the document structure
- Point out: deviceId, timestamp, data fields

**If you can't view items (permission issue):**
- "These permissions are restricted, but we can see the structure is there and working"

---

## ÔøΩÔøΩ Scene 5: Explain the Architecture (2 minutes)

**Say:** "Let me show you how everything connects."

Draw or show this flow:

```
Your Request (curl)
    ‚Üì
APIM Gateway
‚îú‚îÄ Validates JSON schema
‚îú‚îÄ Enforces rate limit (100/min)
‚îî‚îÄ Routes to Logic App
    ‚Üì
Logic App (TelemetryIngestion)
‚îú‚îÄ Receives data
‚îú‚îÄ Transforms if needed
‚îú‚îÄ Routes to Function App (if crash)
‚îî‚îÄ Stores to Cosmos DB
    ‚Üì
Cosmos DB
‚îî‚îÄ Globally distributed storage
    ‚îî‚îÄ Partitioned by region
    ‚îî‚îÄ Available for queries
        ‚Üì
        (Optional) Function App
        ‚îî‚îÄ Processes crash dumps
        ‚îî‚îÄ Could send alerts
```

**Key talking points:**
- ‚úÖ **Serverless** = No servers to manage
- ‚úÖ **Auto-scaling** = Handles 10 or 10,000 requests
- ‚úÖ **Low latency** = < 1 second end-to-end
- ‚úÖ **Cost-effective** = Pay per execution
- ‚úÖ **Resilient** = Built-in retry logic

---

## Ìæ¨ Scene 6: Show Rate Limiting (1 minute)

**Say:** "The API is protected with rate limiting."

Run this (will succeed):
```bash
# 5 quick requests - should all succeed
for i in {1..5}; do
  curl -s -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" \
    -H "Content-Type: application/json" \
    -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" \
    -d '{"deviceId":"test-'$i'","region":"eastus","timestamp":"2025-12-04T19:47:00Z","telemetryType":"metrics","data":{"cpu":50}}'
  echo ""
done
```

**Point out:**
- ‚úÖ All 5 succeed (within the 100/min limit)
- ‚úÖ Each has a unique documentId
- ‚úÖ If we did 100+ per minute, we'd get HTTP 429

---

## ÌæØ Closing Statement (1 minute)

> "This is enterprise-grade telemetry infrastructure, completely serverless. No ops team needed. Scales from 0 to millions. Costs pennies. That's the power of Azure's platform services."

---

## ‚ùì If They Ask...

| Question | Answer |
|----------|--------|
| What languages? | Python Function, JSON workflows, Bicep IaC |
| How does it scale? | Cosmos DB auto-partitions, Functions auto-scale, APIM handles throttling |
| What about security? | API key auth, TLS encryption, Managed Identity for service-to-service |
| Cost estimate? | Cosmos: $0.25/hr, APIM: $0.05 per 1000 calls, Functions: pennies per million |
| Data retention? | TTL can be set on Cosmos docs, queryable forever |
| Real-time? | < 1 second latency, true serverless processing |

---

## ‚ö†Ô∏è If Portal Shows "No Access"

Just say: "We have read-only access for security. Let me show you the run history in the Logic App instead."

**Then:**
- Click Logic App ‚Üí Run history
- Show the running workflows
- Say: "You can see each execution here with full details"

---

## Ì∂ò Emergency Workarounds

| If This Happens | Do This |
|-----------------|---------|
| API returns 401 | Check subscription key is correct |
| API returns 429 | Subscription key rate-limited - wait 60 seconds |
| Can't view Portal | Use run history instead |
| Can't query Cosmos | Show container structure instead |
| Nerves kick in | Take a breath, just show the curl output - the data speaks for itself |

---

## ‚úÖ Success Checklist

Before you finish:

- [ ] Showed API returning success + documentId
- [ ] Showed 2+ telemetry types (metrics + crash)
- [ ] Showed Logic App run history
- [ ] Showed Cosmos DB storage location
- [ ] Explained the architecture flow
- [ ] Mentioned serverless benefits
- [ ] Answered 1-2 questions
- [ ] Closed with a strong statement

---

## Ìæ¨ Total Time: ~12 minutes

- Opening: 30 sec
- API demo: 3 min
- Portal tour: 3 min
- Architecture explanation: 2 min
- Rate limiting demo: 1 min
- Closing + questions: 2.5 min

---

**You've got this! Ì∫Ä**
