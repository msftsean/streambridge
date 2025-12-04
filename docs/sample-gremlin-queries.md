# 🔗 StreamBridge - Sample Gremlin Queries

[![Cosmos DB](https://img.shields.io/badge/Cosmos_DB-Gremlin_API-0078D4?style=for-the-badge&logo=microsoftazure)](https://azure.microsoft.com/services/cosmos-db/)
[![Graph](https://img.shields.io/badge/Graph-TinkerPop-green?style=for-the-badge)](https://tinkerpop.apache.org/)

> 📊 Connect to the Gremlin endpoint using Azure Portal Data Explorer or Gremlin Console.

---

## 🔌 Connection Details

| Property | Value |
|----------|-------|
| 🌐 **Gremlin Endpoint** | `wss://streambridgegraphdb.gremlin.cosmos.azure.com:443/` |
| 📁 **Database** | `StreamBridgeGraph` |
| 📊 **Graph** | `TelemetryGraph` |
| 🔑 **Partition Key** | `/region` |

---

## 📥 Insert Sample Data

### ➕ Add Event Nodes

```gremlin
// 📊 Add telemetry event nodes
g.addV('Event')
  .property('id', 'event-001')
  .property('region', 'eastus')
  .property('name', 'AppStart')
  .property('deviceId', 'device-001')
  .property('timestamp', '2024-12-04T10:00:00Z')

g.addV('Event')
  .property('id', 'event-002')
  .property('region', 'eastus')
  .property('name', 'ClickButton')
  .property('deviceId', 'device-001')
  .property('timestamp', '2024-12-04T10:00:05Z')

g.addV('Event')
  .property('id', 'event-003')
  .property('region', 'eastus')
  .property('name', 'PageLoad')
  .property('deviceId', 'device-001')
  .property('timestamp', '2024-12-04T10:00:10Z')

g.addV('Event')
  .property('id', 'event-004')
  .property('region', 'eastus')
  .property('name', 'CrashEvent')
  .property('deviceId', 'device-001')
  .property('timestamp', '2024-12-04T10:00:15Z')
  .property('errorCode', '0xC0000005')
```

### 🖥️ Add Device Nodes

```gremlin
g.addV('Device')
  .property('id', 'device-001')
  .property('region', 'eastus')
  .property('name', 'Windows-PC-001')
  .property('platform', 'Windows')

g.addV('Device')
  .property('id', 'device-002')
  .property('region', 'westus2')
  .property('name', 'Mac-Laptop-002')
  .property('platform', 'macOS')
```

### 🔗 Add Edges (Relationships)

```gremlin
// ➡️ Event sequence edges
g.V('event-001').addE('next').to(g.V('event-002')).property('duration', 5)
g.V('event-002').addE('next').to(g.V('event-003')).property('duration', 5)
g.V('event-003').addE('next').to(g.V('event-004')).property('duration', 5)

// 🖥️ Device ownership edges
g.V('device-001').addE('generated').to(g.V('event-001'))
g.V('device-001').addE('generated').to(g.V('event-002'))
g.V('device-001').addE('generated').to(g.V('event-003'))
g.V('device-001').addE('generated').to(g.V('event-004'))
```

---

## 🔍 Query Examples

### 📊 Basic Queries

<details>
<summary>🔢 Count all nodes</summary>

```gremlin
g.V().count()
```

**Returns:** Total number of vertices in the graph
</details>

<details>
<summary>📈 Count by label</summary>

```gremlin
g.V().groupCount().by(label)
```

**Returns:** `{Event: 4, Device: 2}`
</details>

<details>
<summary>📋 Get all events</summary>

```gremlin
g.V().hasLabel('Event').valueMap(true)
```

**Returns:** All event vertices with their properties
</details>

<details>
<summary>🌍 Get events by region</summary>

```gremlin
g.V().hasLabel('Event').has('region', 'eastus').valueMap('name', 'timestamp')
```

**Returns:** Events filtered by partition key
</details>

---

### 🔗 Relationship Queries

<details>
<summary>➡️ Find events connected to a specific event</summary>

```gremlin
g.V('event-001').out('next').values('name')
```

**Returns:** Names of events that follow `event-001`
</details>

<details>
<summary>🔄 Get the full event chain</summary>

```gremlin
g.V('event-001').repeat(out('next')).until(outE().count().is(0)).path().by('name')
```

**Returns:** Complete path from first event to last
</details>

<details>
<summary>💥 Find all events leading to a crash</summary>

```gremlin
g.V().hasLabel('Event').has('name', 'CrashEvent')
  .repeat(__.in('next')).emit().path().by('name')
```

**Returns:** Event sequence that led to crash
</details>

---

### 🛤️ Path Analysis

<details>
<summary>📍 Get most common paths (3 steps)</summary>

```gremlin
g.V().hasLabel('Event')
  .repeat(out('next')).times(3)
  .path().by('name')
```

**Returns:** All 3-step paths through events
</details>

<details>
<summary>🔍 Find path between two events</summary>

```gremlin
g.V('event-001').repeat(out('next').simplePath())
  .until(hasId('event-004'))
  .path().by('name')
```

**Returns:** Path from `event-001` to `event-004`
</details>

<details>
<summary>📊 Count events per device</summary>

```gremlin
g.V().hasLabel('Device')
  .project('device', 'eventCount')
  .by('name')
  .by(out('generated').count())
```

**Returns:** Device names with their event counts
</details>

---

### 💥 Crash Analysis

<details>
<summary>🖥️ Find devices with crashes</summary>

```gremlin
g.V().hasLabel('Event').has('name', 'CrashEvent')
  .in('generated')
  .dedup()
  .valueMap('name', 'platform')
```

**Returns:** Devices that experienced crashes
</details>

<details>
<summary>📊 Get crash frequency by error code</summary>

```gremlin
g.V().hasLabel('Event').has('name', 'CrashEvent')
  .groupCount().by('errorCode')
```

**Returns:** `{0xC0000005: 3, 0x80004005: 1}`
</details>

<details>
<summary>⏪ Find events before crash (last 3)</summary>

```gremlin
g.V().hasLabel('Event').has('name', 'CrashEvent')
  .repeat(__.in('next')).times(3)
  .path().by('name')
```

**Returns:** 3 events preceding each crash
</details>

---

### 🚀 Advanced Analytics

<details>
<summary>🔄 Find common event sequences</summary>

```gremlin
g.V().hasLabel('Event')
  .as('e1').out('next').as('e2').out('next').as('e3')
  .select('e1', 'e2', 'e3').by('name')
  .groupCount()
  .order(local).by(values, desc)
```

**Returns:** Most frequent 3-event sequences
</details>

<details>
<summary>⏱️ Get average time between events</summary>

```gremlin
g.E().hasLabel('next')
  .values('duration')
  .mean()
```

**Returns:** Average duration in seconds
</details>

<details>
<summary>🔍 Find orphan events (no connections)</summary>

```gremlin
g.V().hasLabel('Event')
  .where(__.not(bothE()))
  .valueMap('id', 'name')
```

**Returns:** Events with no incoming/outgoing edges
</details>

---

## 🖥️ Running Queries

### 🌐 Azure Portal

| Step | Action |
|------|--------|
| 1️⃣ | Go to **Azure Portal** → **Cosmos DB Account** (`streambridgegraphdb`) |
| 2️⃣ | Click **Data Explorer** |
| 3️⃣ | Expand **StreamBridgeGraph** → **TelemetryGraph** |
| 4️⃣ | Click **New Graph Query** |
| 5️⃣ | Enter Gremlin query and click **Execute** ▶️ |

### 💻 Gremlin Console

```bash
# 🚀 Connect to Cosmos DB Gremlin endpoint
bin/gremlin.sh

gremlin> :remote connect tinkerpop.server conf/remote-secure.yaml
gremlin> :remote console
gremlin> g.V().count()
```

### ⚙️ Configuration (remote-secure.yaml)

```yaml
hosts: [streambridgegraphdb.gremlin.cosmos.azure.com]
port: 443
username: /dbs/StreamBridgeGraph/colls/TelemetryGraph
password: <your-primary-key>
connectionPool: {
  enableSsl: true
}
serializer: {
  className: org.apache.tinkerpop.gremlin.driver.ser.GraphSONMessageSerializerV2d0,
  config: { serializeResultToString: true }
}
```

---

## 📋 Query Cheat Sheet

| Query Type | Gremlin Command | Description |
|------------|-----------------|-------------|
| 🔢 Count vertices | `g.V().count()` | Total vertices |
| 🔢 Count edges | `g.E().count()` | Total edges |
| 🏷️ Get labels | `g.V().label().dedup()` | All vertex labels |
| 🔍 Find by ID | `g.V('id')` | Get vertex by ID |
| ➡️ Outgoing edges | `g.V('id').out()` | Connected vertices |
| ⬅️ Incoming edges | `g.V('id').in()` | Source vertices |
| 🔗 Both directions | `g.V('id').both()` | All neighbors |
| 📊 Properties | `g.V('id').valueMap()` | Get all properties |
| 🗑️ Delete vertex | `g.V('id').drop()` | Remove vertex |
| 🗑️ Delete edge | `g.E('id').drop()` | Remove edge |

---

<p align="center">
  <b>🔗 Graph Analytics Ready!</b><br>
  <sub>StreamBridge - Cosmos DB Gremlin API</sub>
</p>
