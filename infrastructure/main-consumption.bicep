// StreamBridge - Simplified Bicep Template (No VM Quota Required)
// Uses Logic Apps Consumption (classic) instead of Standard

@description('The location for all resources')
param location string = resourceGroup().location

@description('Unique suffix for resource names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

// Resource naming
var baseName = 'streambridge'
var cosmosAccountName = '${baseName}cosmos${uniqueSuffix}'
var apimName = '${baseName}apim${uniqueSuffix}'
var logicAppName = '${baseName}logic${uniqueSuffix}'
var appInsightsName = '${baseName}insights${uniqueSuffix}'
var logAnalyticsName = '${baseName}logs${uniqueSuffix}'

var tags = {
  project: 'streambridge'
  environment: 'dev'
}

// ============================================
// Log Analytics Workspace
// ============================================
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ============================================
// Application Insights
// ============================================
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ============================================
// Cosmos DB (Serverless - No VM Required)
// ============================================
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosAccountName
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
        name: 'EnableServerless'
      }
    ]
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: 'StreamBridgeDemo'
  properties: {
    resource: {
      id: 'StreamBridgeDemo'
    }
  }
}

resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: cosmosDatabase
  name: 'TelemetryData'
  properties: {
    resource: {
      id: 'TelemetryData'
      partitionKey: {
        paths: ['/region']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [{ path: '/*' }]
        excludedPaths: [{ path: '/_etag/?' }]
      }
    }
  }
}

// ============================================
// Logic App (Consumption - No VM Required)
// ============================================
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            method: 'POST'
            schema: {
              type: 'object'
              properties: {
                deviceId: { type: 'string' }
                region: { type: 'string' }
                timestamp: { type: 'string' }
                telemetryType: { type: 'string' }
                data: { type: 'object' }
                crashDump: { type: 'object' }
              }
              required: ['deviceId', 'region', 'timestamp', 'telemetryType']
            }
          }
        }
      }
      actions: {
        Initialize_DocumentId: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'documentId'
                type: 'string'
                value: '@{guid()}'
              }
            ]
          }
          runAfter: {}
        }
        Check_CrashDump: {
          type: 'If'
          expression: {
            and: [
              {
                not: {
                  equals: ['@triggerBody()?[\'crashDump\']', null]
                }
              }
            ]
          }
          actions: {
            Process_CrashDump: {
              type: 'Compose'
              inputs: {
                status: 'processed'
                crashSignature: '@{substring(guid(), 0, 8)}'
                severity: 'Medium'
                processedAt: '@{utcNow()}'
              }
            }
          }
          else: {
            actions: {
              Skip_Processing: {
                type: 'Compose'
                inputs: {
                  status: 'stored'
                  message: 'No crash dump to process'
                }
              }
            }
          }
          runAfter: {
            Initialize_DocumentId: ['Succeeded']
          }
        }
        Response: {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              success: true
              documentId: '@variables(\'documentId\')'
              message: 'Telemetry ingested successfully'
              timestamp: '@{utcNow()}'
            }
          }
          runAfter: {
            Check_CrashDump: ['Succeeded']
          }
        }
      }
    }
  }
}

// ============================================
// API Management (Consumption - No VM Required)
// ============================================
resource apim 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: 'admin@streambridge.demo'
    publisherName: 'StreamBridge Demo'
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apim
  name: 'streambridge-api'
  properties: {
    displayName: 'StreamBridge Telemetry API'
    description: 'API for ingesting telemetry and crash dump metadata'
    path: 'telemetry'
    protocols: ['https']
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
  }
}

resource uploadOperation 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  parent: api
  name: 'upload-telemetry'
  properties: {
    displayName: 'Upload Telemetry'
    method: 'POST'
    urlTemplate: '/uploadTelemetry'
    description: 'Upload telemetry data and crash dump metadata'
    request: {
      description: 'Telemetry payload'
      representations: [{ contentType: 'application/json' }]
    }
    responses: [
      { statusCode: 200, description: 'Success' }
      { statusCode: 400, description: 'Invalid payload' }
      { statusCode: 429, description: 'Rate limit exceeded' }
    ]
  }
}

// Named value for Logic App URL
resource logicAppUrlNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apim
  name: 'LogicAppUrl'
  properties: {
    displayName: 'LogicAppUrl'
    value: listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', logicApp.name, 'manual'), '2019-05-01').value
    secret: true
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  parent: api
  name: 'policy'
  dependsOn: [logicAppUrlNamedValue]
  properties: {
    value: '<policies><inbound><base /><rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Subscription?.Key ?? context.Request.IpAddress)" /><set-backend-service base-url="{{LogicAppUrl}}" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
    format: 'xml'
  }
}

resource product 'Microsoft.ApiManagement/service/products@2023-03-01-preview' = {
  parent: apim
  name: 'streambridge-product'
  properties: {
    displayName: 'StreamBridge'
    description: 'Access to StreamBridge Telemetry API'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

resource productApi 'Microsoft.ApiManagement/service/products/apis@2023-03-01-preview' = {
  parent: product
  name: api.name
}

resource apiSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  parent: apim
  name: 'demo-subscription'
  properties: {
    displayName: 'Demo Subscription'
    scope: '/products/${product.id}'
    state: 'active'
  }
}

// ============================================
// Role Assignment - Logic App to Cosmos DB
// ============================================
resource cosmosRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, logicApp.id, 'cosmos-contributor')
  properties: {
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    principalId: logicApp.identity.principalId
    scope: cosmosAccount.id
  }
}

// ============================================
// Outputs
// ============================================
output cosmosAccountName string = cosmosAccount.name
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output logicAppName string = logicApp.name
output logicAppTriggerUrl string = listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', logicApp.name, 'manual'), '2019-05-01').value
output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output apiEndpoint string = '${apim.properties.gatewayUrl}/telemetry/uploadTelemetry'
