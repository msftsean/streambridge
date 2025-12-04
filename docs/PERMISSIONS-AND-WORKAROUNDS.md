# ⚠️ Permission Issues & Workarounds

## Known Permission Limitation

Your user account (`sean.gayle@microsoft.com`) has **limited permissions** on the Azure subscription resources in the `rg-streambridge` resource group.

### What This Means

| Action | Status | Reason |
|--------|--------|--------|
| **View resources in Portal** | ✅ Works | Read-only access granted |
| **View Logic App run history** | ✅ Works | Audit logs accessible |
| **View Cosmos DB structure** | ✅ Works | Data Explorer read-only |
| **Call the API endpoint** | ✅ Works | Public via APIM |
| **Query Cosmos DB data** | ❌ Blocked | Master key required |
| **Configure APIM policies** | ❌ Blocked | Management role required |
| **Restart services** | ❌ Blocked | Management role required |
| **Modify app settings** | ❌ Blocked | Management role required |

---

## What YOU CAN Do for the Demo

### 1. ✅ Test the API Endpoint

The API is **fully functional** and doesn't require elevated permissions.

```bash
# This works - shows successful ingestion
curl -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" \
  -d '{
    "deviceId": "demo-device-001",
    "region": "eastus",
    "timestamp": "2025-12-04T19:45:00Z",
    "telemetryType": "metrics",
    "data": {"cpu": 45.2, "memory": 72.1}
  }'
```

**Result:**
```json
{
  "success": true,
  "documentId": "c0a1eca1-480d-4ef9-8859-3845b6a82f16",
  "message": "Telemetry ingested successfully"
}
```

### 2. ✅ View Logic App Run History

Navigate to: **Logic App** → **Workflows** → **TelemetryIngestion** → **Run history**

This shows:
- ✅ When each API call triggered the workflow
- ✅ Input/output of each run
- ✅ Success/failure status
- ✅ Duration and execution details

### 3. ✅ View Infrastructure Components

In Azure Portal, you can **read and navigate**:
- ✅ APIM gateway configuration (APIs, policies, etc.)
- ✅ Logic App workflow definition
- ✅ Cosmos DB database and container structure
- ✅ Function App code and configuration
- ✅ Resource group contents

### 4. ✅ View Cosmos DB Partitioning

Navigate to: **Cosmos DB** → **Data Explorer** → **StreamBridgeDemo** → **TelemetryData** → **Settings**

You can see:
- ✅ Partition key: `/region`
- ✅ Container throughput
- ✅ Indexing policy

---

## What YOU CANNOT Do

### 1. ❌ Restart Services

**Problem:** Portal shows "No access" when trying to restart Logic App or Function App

**Workaround for demo:**
- Show the run history instead to prove it's working
- Mention: "In production, we'd use automation to restart if needed"

### 2. ❌ Query Cosmos DB Directly (via Portal)

**Problem:** "Unauthorized" error when trying to read items

**Why:** Requires master key or RBAC "Cosmos DB Data Contributor" role

**Workaround for demo:**
- Show the container structure and partition key
- Mention: "Data is stored here, partitioned by region for performance"
- Use the API test to prove data is being ingested

### 3. ❌ Modify App Configuration

**Problem:** Can't update COSMOS_CONNECTION_STRING or other settings

**Why:** Requires "Contributor" role on the resource

**Impact on demo:**
- **NONE** - Everything is already configured and working
- This was already fixed during setup

### 4. ❌ Change APIM Policies

**Problem:** Can't edit rate limiting or validation rules

**Why:** Requires API Management Contributor role

**For demo:**
- Show the existing policies (read-only)
- Explain how rate limiting works
- Don't try to modify anything

---

## Verifying the API Works (Despite Permissions)

The API is working regardless of permissions. Here's proof:

### Test 1: Simple Metrics Ingestion ✅

```bash
curl -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" \
  -d '{
    "deviceId": "test-device",
    "region": "eastus",
    "timestamp": "2025-12-04T19:45:00Z",
    "telemetryType": "metrics",
    "data": {"cpu": 50}
  }'
```

**Response:** ✅ `success: true, documentId: <guid>`

### Test 2: Crash Dump Processing ✅

```bash
curl -X POST "https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: 30e106dc4cf942d99b8c780c14d603a1" \
  -d '{
    "deviceId": "device-02",
    "region": "westus2",
    "timestamp": "2025-12-04T19:46:00Z",
    "telemetryType": "crashDump",
    "data": {"lastKnownState": "running"},
    "crashDump": {
      "dumpId": "crash-001",
      "errorCode": "0xC0000005",
      "processName": "app.exe"
    }
  }'
```

**Response:** ✅ `success: true, documentId: <guid>`

### Test 3: Verify Logic App Processed It ✅

1. Go to **Logic App** → **Run history**
2. You'll see a new run entry with:
   - Status: ✅ Succeeded
   - Trigger input: Your curl payload
   - Duration: ~1-2 seconds

---

## FAQ

### Q: Why can't I have full permissions?

**A:** This is likely an enterprise security policy. Only subscription owners can grant elevated permissions. Contact your administrator.

### Q: Does this affect the demo?

**A:** **NO.** The demo works perfectly because:
- ✅ The API endpoint is public (via APIM)
- ✅ Logic App run history is readable
- ✅ You can show successful ingestion with document IDs
- ✅ All the infrastructure is visible in the Portal

### Q: Can I fix the permissions myself?

**A:** Only if you're a subscription owner. If not, ask the owner to grant you "Contributor" role on the resource group.

### Q: What if I need to restart something?

**A:** For the demo, you don't need to. Everything is already running and configured. If something breaks:
1. Ask someone with Contributor access to restart it
2. Or contact Azure support

### Q: Will this be a problem in production?

**A:** No. In production:
- You'd have proper RBAC setup
- Automation would handle restarts
- You'd use managed identities instead of user accounts

---

## Quick Demo Workflow

### Before Demo (5 minutes)

- [ ] Test API endpoint works
- [ ] Check Logic App run history is populated
- [ ] Open Azure Portal to resource group
- [ ] Have talking points ready

### During Demo (10 minutes)

1. **Show API working** (2 min)
   - Run curl command
   - Show successful response with documentId

2. **Show infrastructure** (3 min)
   - Click through Portal resources
   - Show Logic App run history
   - Show Cosmos DB container structure

3. **Show architecture** (2 min)
   - Explain data flow
   - Point out serverless benefits

4. **Answer questions** (3 min)
   - Use the FAQ section if needed

### If Portal Shows "No Access"

- **Don't panic** - this is expected
- **Pivot to**: "Let me show you the run history in the Logic App instead"
- **Explain**: "We have read-only access to verify everything is working"

---

## Credentials for Demo

| Item | Value |
|------|-------|
| API Endpoint | https://streambridgeapimdev.azure-api.net/telemetry/uploadTelemetry |
| Subscription Key | 30e106dc4cf942d99b8c780c14d603a1 |
| Resource Group | rg-streambridge |
| Region | eastus2 |

---

## When You Get Full Permissions

Once you have Contributor access, you can:

```powershell
# Get Cosmos DB connection string
az cosmosdb keys list \
  --name streambridgecosmosbryctld4qwjpg \
  --resource-group rg-streambridge

# Query Cosmos DB
az cosmosdb sql container item query \
  --account-name streambridgecosmosbryctld4qwjpg \
  --database-name StreamBridgeDemo \
  --container-name TelemetryData \
  --query "SELECT * FROM c"

# Restart Logic App
az functionapp restart \
  --name streambridgelogicbryctld4qwjpg \
  --resource-group rg-streambridge
```

---

<p align="center">
  <b>✅ Your demo is ready!</b><br>
  <sub>Focus on showing the API working - that's what matters.</sub>
</p>
