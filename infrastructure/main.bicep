// StreamBridge - Main Bicep Deployment Template
// Deploys: Cosmos DB, Function App, Logic App, API Management

@description('The location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Unique suffix for resource names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

// Resource naming
var baseName = 'streambridge'
var cosmosAccountName = '${baseName}-cosmos-${uniqueSuffix}'
var functionAppName = '${baseName}-func-${uniqueSuffix}'
var logicAppName = '${baseName}-logic-${uniqueSuffix}'
var apimName = '${baseName}-apim-${uniqueSuffix}'
var storageAccountName = '${baseName}stor${uniqueSuffix}'
var appServicePlanName = '${baseName}-asp-${uniqueSuffix}'
var appInsightsName = '${baseName}-insights-${uniqueSuffix}'
var logAnalyticsName = '${baseName}-logs-${uniqueSuffix}'

// ============================================
// Log Analytics Workspace (for App Insights)
// ============================================
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
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
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ============================================
// Cosmos DB Account and Database
// ============================================
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    enableFreeTier: true
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
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/_etag/?'
          }
        ]
      }
    }
  }
}

// ============================================
// Storage Account (for Function App)
// ============================================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// ============================================
// App Service Plan (Consumption for Functions)
// ============================================
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true // Linux
  }
}

// ============================================
// Function App
// ============================================
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      pythonVersion: '3.11'
      linuxFxVersion: 'PYTHON|3.11'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'COSMOS_ENDPOINT'
          value: cosmosAccount.properties.documentEndpoint
        }
        {
          name: 'COSMOS_DATABASE'
          value: 'StreamBridgeDemo'
        }
        {
          name: 'COSMOS_CONTAINER'
          value: 'TelemetryData'
        }
      ]
    }
  }
}

// ============================================
// Logic App (Standard - Workflow)
// ============================================
resource logicAppStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${baseName}lastor${uniqueSuffix}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource logicAppPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${logicAppName}-plan'
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
  }
  properties: {
    targetWorkerCount: 1
    targetWorkerSizeId: 1
    maximumElasticWorkerCount: 3
  }
}

resource logicApp 'Microsoft.Web/sites@2022-09-01' = {
  name: logicAppName
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: logicAppPlan.id
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v6.0'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${logicAppStorageAccount.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${logicAppStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${logicAppStorageAccount.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${logicAppStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: logicAppName
        }
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'COSMOS_CONNECTION_STRING'
          value: cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
        }
        {
          name: 'FUNCTION_APP_URL'
          value: 'https://${functionApp.properties.defaultHostName}'
        }
      ]
    }
  }
}

// ============================================
// API Management (Consumption Tier)
// ============================================
resource apim 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apimName
  location: location
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

// API Definition
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

// Upload Telemetry Operation
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
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Telemetry accepted successfully'
      }
      {
        statusCode: 400
        description: 'Invalid payload'
      }
      {
        statusCode: 429
        description: 'Rate limit exceeded'
      }
    ]
  }
}

// Rate Limiting Policy
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    value: '''
<policies>
    <inbound>
        <base />
        <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Subscription?.Key ?? context.Request.IpAddress)" />
        <validate-content unspecified-content-type-action="prevent" max-size="102400" size-exceeded-action="prevent" errors-variable-name="validationErrors">
            <content type="application/json" validate-as="json" action="prevent" />
        </validate-content>
        <set-backend-service base-url="https://${logicAppName}.azurewebsites.net:443/api/TelemetryIngestion/triggers/manual/invoke" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
'''
    format: 'xml'
  }
}

// Product for API
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

// Link API to Product
resource productApi 'Microsoft.ApiManagement/service/products/apis@2023-03-01-preview' = {
  parent: product
  name: api.name
}

// Subscription for testing
resource subscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  parent: apim
  name: 'demo-subscription'
  properties: {
    displayName: 'Demo Subscription'
    scope: '/products/${product.id}'
    state: 'active'
  }
}

// ============================================
// Role Assignments
// ============================================

// Cosmos DB Data Contributor role for Logic App
resource cosmosRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, logicApp.id, 'cosmos-data-contributor')
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
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output logicAppName string = logicApp.name
output logicAppUrl string = 'https://${logicApp.properties.defaultHostName}'
output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output apiEndpoint string = '${apim.properties.gatewayUrl}/telemetry/uploadTelemetry'
output resourceGroupName string = resourceGroup().name
