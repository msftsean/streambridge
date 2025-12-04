#!/bin/bash
# StreamBridge - Cosmos DB Setup Script (Bash)
# Creates database and container with proper configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DATABASE_NAME="StreamBridgeDemo"
CONTAINER_NAME="TelemetryData"
PARTITION_KEY_PATH="/region"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -a|--account)
            COSMOS_ACCOUNT="$2"
            shift 2
            ;;
        -d|--database)
            DATABASE_NAME="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ]; then
    echo -e "${RED}Error: Resource group is required. Use -g or --resource-group${NC}"
    echo "Usage: $0 -g <resource-group> [-a <cosmos-account>] [-d <database>] [-c <container>]"
    exit 1
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}StreamBridge - Cosmos DB Setup${NC}"
echo -e "${CYAN}========================================${NC}"

# Get Cosmos DB account if not provided
if [ -z "$COSMOS_ACCOUNT" ]; then
    echo -e "\n${YELLOW}Finding Cosmos DB account in resource group...${NC}"
    COSMOS_ACCOUNT=$(az cosmosdb list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
    if [ -z "$COSMOS_ACCOUNT" ]; then
        echo -e "${RED}No Cosmos DB accounts found in resource group: $RESOURCE_GROUP${NC}"
        exit 1
    fi
    echo -e "${GREEN}Found Cosmos DB account: $COSMOS_ACCOUNT${NC}"
fi

# Check if database exists
echo -e "\n${YELLOW}Checking for existing database...${NC}"
EXISTING_DB=$(az cosmosdb sql database show \
    --account-name "$COSMOS_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DATABASE_NAME" \
    --query "name" -o tsv 2>/dev/null || true)

if [ -n "$EXISTING_DB" ]; then
    echo -e "${GREEN}Database '$DATABASE_NAME' already exists${NC}"
else
    echo -e "${YELLOW}Creating database: $DATABASE_NAME${NC}"
    az cosmosdb sql database create \
        --account-name "$COSMOS_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DATABASE_NAME"
    echo -e "${GREEN}Database created successfully!${NC}"
fi

# Check if container exists
echo -e "\n${YELLOW}Checking for existing container...${NC}"
EXISTING_CONTAINER=$(az cosmosdb sql container show \
    --account-name "$COSMOS_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --database-name "$DATABASE_NAME" \
    --name "$CONTAINER_NAME" \
    --query "name" -o tsv 2>/dev/null || true)

if [ -n "$EXISTING_CONTAINER" ]; then
    echo -e "${GREEN}Container '$CONTAINER_NAME' already exists${NC}"
else
    echo -e "${YELLOW}Creating container: $CONTAINER_NAME${NC}"

    # Create indexing policy JSON
    INDEXING_POLICY='{
        "indexingMode": "consistent",
        "automatic": true,
        "includedPaths": [{"path": "/*"}],
        "excludedPaths": [{"path": "/_etag/?"}],
        "compositeIndexes": [
            [
                {"path": "/region", "order": "ascending"},
                {"path": "/timestamp", "order": "descending"}
            ],
            [
                {"path": "/deviceId", "order": "ascending"},
                {"path": "/timestamp", "order": "descending"}
            ]
        ]
    }'

    az cosmosdb sql container create \
        --account-name "$COSMOS_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --database-name "$DATABASE_NAME" \
        --name "$CONTAINER_NAME" \
        --partition-key-path "$PARTITION_KEY_PATH" \
        --indexing-policy "$INDEXING_POLICY"

    echo -e "${GREEN}Container created successfully!${NC}"
fi

# Display connection info
echo -e "\n${CYAN}========================================${NC}"
echo -e "${CYAN}Cosmos DB Configuration Complete${NC}"
echo -e "${CYAN}========================================${NC}"

ENDPOINT=$(az cosmosdb show \
    --name "$COSMOS_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --query "documentEndpoint" -o tsv)

echo -e "\n${YELLOW}Connection Details:${NC}"
echo "  Account:    $COSMOS_ACCOUNT"
echo "  Database:   $DATABASE_NAME"
echo "  Container:  $CONTAINER_NAME"
echo "  Partition:  $PARTITION_KEY_PATH"
echo "  Endpoint:   $ENDPOINT"

echo -e "\n${CYAN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${CYAN}========================================${NC}"
