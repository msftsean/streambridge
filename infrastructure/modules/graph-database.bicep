// StreamBridge - Cosmos DB Graph Database Module
// Creates Gremlin API database for graph analytics

@description('Location for the graph database')
param location string

@description('Tags for resources')
param tags object

@description('Unique suffix for naming')
param uniqueSuffix string

var graphAccountName = 'streambridgegraph${uniqueSuffix}'

// ============================================
// Cosmos DB Account with Gremlin API
// ============================================
resource graphAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: graphAccountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: false
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableGremlin'
      }
    ]
  }
}

// ============================================
// Gremlin Database
// ============================================
resource graphDatabase 'Microsoft.DocumentDB/databaseAccounts/gremlinDatabases@2023-04-15' = {
  parent: graphAccount
  name: 'StreamBridgeGraph'
  properties: {
    resource: {
      id: 'StreamBridgeGraph'
    }
  }
}

// ============================================
// Gremlin Graph Container
// ============================================
resource graphContainer 'Microsoft.DocumentDB/databaseAccounts/gremlinDatabases/graphs@2023-04-15' = {
  parent: graphDatabase
  name: 'TelemetryGraph'
  properties: {
    resource: {
      id: 'TelemetryGraph'
      partitionKey: {
        paths: ['/region']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [{ path: '/*' }]
        excludedPaths: [{ path: '/"_etag"/?' }]
      }
    }
    options: {
      throughput: 400
    }
  }
}

// ============================================
// Outputs
// ============================================
output graphAccountName string = graphAccount.name
output graphEndpoint string = graphAccount.properties.documentEndpoint
output gremlinEndpoint string = 'wss://${graphAccount.name}.gremlin.cosmos.azure.com:443/'
output databaseName string = graphDatabase.name
output graphName string = graphContainer.name
