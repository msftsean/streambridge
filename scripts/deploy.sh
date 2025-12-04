#!/bin/bash
# StreamBridge - Deployment Script (Bash)
# Deploys all Azure resources using Bicep

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
RESOURCE_GROUP="rg-streambridge"
LOCATION="eastus2"
ENVIRONMENT="dev"
DEPLOY_FUNCTION=false
DEPLOY_LOGIC_APP=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --deploy-function)
            DEPLOY_FUNCTION=true
            shift
            ;;
        --deploy-logic-app)
            DEPLOY_LOGIC_APP=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}StreamBridge - Azure Deployment${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location:       $LOCATION"
echo "  Environment:    $ENVIRONMENT"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BICEP_PATH="$SCRIPT_DIR/../infrastructure/main.bicep"

# Check Azure CLI
echo -e "${YELLOW}Checking Azure CLI...${NC}"
if ! command -v az &> /dev/null; then
    echo -e "${RED}Azure CLI not found. Please install it.${NC}"
    exit 1
fi
AZ_VERSION=$(az version --query '"azure-cli"' -o tsv)
echo -e "${GREEN}Azure CLI version: $AZ_VERSION${NC}"

# Check login
echo -e "\n${YELLOW}Checking Azure login status...${NC}"
ACCOUNT=$(az account show --query "name" -o tsv 2>/dev/null || true)
if [ -z "$ACCOUNT" ]; then
    echo -e "${YELLOW}Not logged in. Running 'az login'...${NC}"
    az login
    ACCOUNT=$(az account show --query "name" -o tsv)
fi
echo -e "${GREEN}Logged in to subscription: $ACCOUNT${NC}"

# Create resource group
echo -e "\n${YELLOW}Creating resource group: $RESOURCE_GROUP...${NC}"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags "project=streambridge" "environment=$ENVIRONMENT" > /dev/null
echo -e "${GREEN}Resource group created!${NC}"

# Deploy Bicep
echo -e "\n${CYAN}========================================${NC}"
echo -e "${CYAN}Deploying Infrastructure (Bicep)${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "${YELLOW}Deploying from: $BICEP_PATH${NC}"
echo -e "${YELLOW}This may take 10-15 minutes...${NC}"
echo ""

OUTPUTS=$(az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$BICEP_PATH" \
    --parameters location="$LOCATION" environment="$ENVIRONMENT" \
    --query "properties.outputs" \
    --output json)

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed!${NC}"
    exit 1
fi

# Parse outputs
COSMOS_ACCOUNT=$(echo "$OUTPUTS" | jq -r '.cosmosAccountName.value')
FUNCTION_APP=$(echo "$OUTPUTS" | jq -r '.functionAppName.value')
FUNCTION_URL=$(echo "$OUTPUTS" | jq -r '.functionAppUrl.value')
LOGIC_APP=$(echo "$OUTPUTS" | jq -r '.logicAppName.value')
LOGIC_URL=$(echo "$OUTPUTS" | jq -r '.logicAppUrl.value')
APIM_NAME=$(echo "$OUTPUTS" | jq -r '.apimName.value')
API_ENDPOINT=$(echo "$OUTPUTS" | jq -r '.apiEndpoint.value')

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Infrastructure Deployed Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Deployment Outputs:${NC}"
echo "  Cosmos Account:  $COSMOS_ACCOUNT"
echo "  Function App:    $FUNCTION_APP"
echo "  Function URL:    $FUNCTION_URL"
echo "  Logic App:       $LOGIC_APP"
echo "  Logic App URL:   $LOGIC_URL"
echo "  APIM:            $APIM_NAME"
echo "  API Endpoint:    $API_ENDPOINT"

# Deploy Function code
if [ "$DEPLOY_FUNCTION" = true ]; then
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}Deploying Function App Code${NC}"
    echo -e "${CYAN}========================================${NC}"

    cd "$SCRIPT_DIR/../function-app"
    echo -e "${YELLOW}Publishing to $FUNCTION_APP...${NC}"
    func azure functionapp publish "$FUNCTION_APP" --python
    echo -e "${GREEN}Function App code deployed!${NC}"
    cd "$SCRIPT_DIR"
fi

# Get subscription key
echo -e "\n${CYAN}========================================${NC}"
echo -e "${CYAN}APIM Subscription Key${NC}"
echo -e "${CYAN}========================================${NC}"

SUBSCRIPTION_KEY=$(az apim subscription show \
    --resource-group "$RESOURCE_GROUP" \
    --service-name "$APIM_NAME" \
    --subscription-id "demo-subscription" \
    --query "primaryKey" -o tsv 2>/dev/null || true)

if [ -n "$SUBSCRIPTION_KEY" ]; then
    echo -e "${YELLOW}Subscription Key: $SUBSCRIPTION_KEY${NC}"
else
    echo -e "${YELLOW}Note: APIM may still be provisioning. Key will be available soon.${NC}"
fi

# Summary
echo -e "\n${CYAN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${YELLOW}Test Command:${NC}"
cat << EOF

curl -X POST '$API_ENDPOINT' \\
  -H 'Content-Type: application/json' \\
  -H 'Ocp-Apim-Subscription-Key: <subscription-key>' \\
  -d '{
    "deviceId": "test-device",
    "region": "eastus",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "telemetryType": "metrics",
    "data": {"cpu": 50, "memory": 75}
  }'
EOF
