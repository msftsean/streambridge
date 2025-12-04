# StreamBridge - Sample Gremlin Queries

Connect to the Gremlin endpoint using Azure Portal Data Explorer or Gremlin Console.

## Connection Details

- **Gremlin Endpoint**: `wss://streambridgegraphdb.gremlin.cosmos.azure.com:443/`
- **Database**: `StreamBridgeGraph`
- **Graph**: `TelemetryGraph`
- **Partition Key**: `/region`

---

## Insert Sample Data

### Add Event Nodes

```gremlin
// Add telemetry event nodes
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

### Add Device Nodes

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

### Add Edges (Relationships)

```gremlin
// Event sequence edges
g.V('event-001').addE('next').to(g.V('event-002')).property('duration', 5)
g.V('event-002').addE('next').to(g.V('event-003')).property('duration', 5)
g.V('event-003').addE('next').to(g.V('event-004')).property('duration', 5)

// Device ownership edges
g.V('device-001').addE('generated').to(g.V('event-001'))
g.V('device-001').addE('generated').to(g.V('event-002'))
g.V('device-001').addE('generated').to(g.V('event-003'))
g.V('device-001').addE('generated').to(g.V('event-004'))
```

---

## Query Examples

### Basic Queries

#### Count all nodes
```gremlin
g.V().count()
```

#### Count by label
```gremlin
g.V().groupCount().by(label)
```

#### Get all events
```gremlin
g.V().hasLabel('Event').valueMap(true)
```

#### Get events by region
```gremlin
g.V().hasLabel('Event').has('region', 'eastus').valueMap('name', 'timestamp')
```

---

### Relationship Queries

#### Find events connected to a specific event
```gremlin
g.V('event-001').out('next').values('name')
```

#### Get the full event chain
```gremlin
g.V('event-001').repeat(out('next')).until(outE().count().is(0)).path().by('name')
```

#### Find all events leading to a crash
```gremlin
g.V().hasLabel('Event').has('name', 'CrashEvent')
  .repeat(__.in('next')).emit().path().by('name')
```

---

### Path Analysis

#### Get most common paths (3 steps)
```gremlin
g.V().hasLabel('Event')
  .repeat(out('next')).times(3)
  .path().by('name')
```

#### Find path between two events
```gremlin
g.V('event-001').repeat(out('next').simplePath())
  .until(hasId('event-004'))
  .path().by('name')
```

#### Count events per device
```gremlin
g.V().hasLabel('Device')
  .project('device', 'eventCount')
  .by('name')
  .by(out('generated').count())
```

---

### Crash Analysis

#### Find devices with crashes
```gremlin
g.V().hasLabel('Event').has('name', 'CrashEvent')
  .in('generated')
  .dedup()
  .valueMap('name', 'platform')
```

#### Get crash frequency by error code
```gremlin
g.V().hasLabel('Event').has('name', 'CrashEvent')
  .groupCount().by('errorCode')
```

#### Find events before crash (last 3)
```gremlin
g.V().hasLabel('Event').has('name', 'CrashEvent')
  .repeat(__.in('next')).times(3)
  .path().by('name')
```

---

### Advanced Analytics

#### Find common event sequences
```gremlin
g.V().hasLabel('Event')
  .as('e1').out('next').as('e2').out('next').as('e3')
  .select('e1', 'e2', 'e3').by('name')
  .groupCount()
  .order(local).by(values, desc)
```

#### Get average time between events
```gremlin
g.E().hasLabel('next')
  .values('duration')
  .mean()
```

#### Find orphan events (no connections)
```gremlin
g.V().hasLabel('Event')
  .where(__.not(bothE()))
  .valueMap('id', 'name')
```

---

## Running Queries

### Azure Portal

1. Go to **Azure Portal** → **Cosmos DB Account** (streambridgegraphdb)
2. Click **Data Explorer**
3. Expand **StreamBridgeGraph** → **TelemetryGraph**
4. Click **New Graph Query**
5. Enter Gremlin query and click **Execute**

### Gremlin Console

```bash
# Connect to Cosmos DB Gremlin endpoint
bin/gremlin.sh

gremlin> :remote connect tinkerpop.server conf/remote-secure.yaml
gremlin> :remote console
gremlin> g.V().count()
```

### Configuration (remote-secure.yaml)

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
