#!/bin/bash
# ======================================================================================
# Deploy-UPNToolchain.sh
#  UPN Alignment Project — Layer 2 & 3 Infrastructure Deployment
#
# Run this in Azure Cloud Shell (Bash). It creates:
#   1. Resource Group
#   2. Storage Account: (with 4 tables)
#   3. Logic App: (from ARM template)
#   4. RBAC assignments for the Logic App's managed identity
#
# Prerequisites:
#   - You must have the ARM template file 'logic-upn-orchestrator.json' uploaded
#     to Cloud Shell (same directory as this script)
#   - You must fill in the configuration variables below before running
#
# Author:  squf — Systems Administrator
# Github: https://github.com/squf/it-tools/Azure/UPN%20Alignment%20Toolchain
# ======================================================================================

set -euo pipefail

# ======================================================================================
# CONFIGURATION — Fill these in before running
# ======================================================================================

SUBSCRIPTION_ID="[replace with your Azure Subscription ID]" # <-- Your Azure Subscription ID (GUID)
AA_RESOURCE_GROUP="[replace with the resource group where Azure Automation Hybrid Worker lives]"

# Pre-filled — these should match your existing environment
AA_NAME="[replace with your Azure Automation Account name]"
HYBRID_WORKER_GROUP="[replace with your Hybrid Worker Group name]"
RUNBOOK_NAME="[replace with your Runbook name that the Logic App will trigger]"

# New resources to be created by this script
RG_NAME="[replace with the name of the resource group to create]"
STORAGE_NAME="[replace with the name of the storage account to create]"
LOGIC_APP_NAME="[replace with the name of the logic app to create]"
LOCATION="[replace with the location of the resources to create]"
MAX_BATCH_SIZE=25

ARM_TEMPLATE="logic-upn-orchestrator.json"

# ======================================================================================
# VALIDATION
# ======================================================================================

echo ""
echo "========================================================================"
echo "   UPN Toolchain — Infrastructure Deployment"
echo "========================================================================"
echo ""

if [ -z "$SUBSCRIPTION_ID" ]; then
    echo "ERROR: SUBSCRIPTION_ID is not set. Edit this script and fill it in."
    exit 1
fi

if [ -z "$AA_RESOURCE_GROUP" ]; then
    echo "ERROR: AA_RESOURCE_GROUP is not set. Edit this script and fill it in."
    exit 1
fi

if [ ! -f "$ARM_TEMPLATE" ]; then
    echo "ERROR: ARM template '$ARM_TEMPLATE' not found in current directory."
    echo "       Upload it to Cloud Shell first: $(pwd)/$ARM_TEMPLATE"
    exit 1
fi

echo "  Subscription     : $SUBSCRIPTION_ID"
echo "  Location          : $LOCATION"
echo "  New Resource Group: $RG_NAME"
echo "  Storage Account   : $STORAGE_NAME"
echo "  Logic App         : $LOGIC_APP_NAME"
echo "  Automation Account: $AA_NAME (in $AA_RESOURCE_GROUP)"
echo "  Runbook           : $RUNBOOK_NAME"
echo "  Hybrid Worker     : $HYBRID_WORKER_GROUP"
echo ""
echo "========================================================================"
echo ""

# ======================================================================================
# [1/8] Set subscription
# ======================================================================================

echo "[1/8] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_ID"
echo "Done."
echo ""

# ======================================================================================
# [2/8] Create resource group
# ======================================================================================

echo "[2/8] Creating resource group: $RG_NAME..."
az group create \
    --name "$RG_NAME" \
    --location "$LOCATION" \
    --tags Project="UPN-Alignment" CostCenter="IT" Environment="Production" ManagedBy="User" \
    --output none
echo "Done."
echo ""

# ======================================================================================
# [3/8] Create storage account
# ======================================================================================

echo "[3/8] Creating storage account: $STORAGE_NAME..."
az storage account create \
    --name "$STORAGE_NAME" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --tags Project="UPN-Alignment" CostCenter="IT" \
    --output none
echo "Done."
echo ""

# ======================================================================================
# [4/8] Create tables
# ======================================================================================

echo "[4/8] Creating tables in $STORAGE_NAME..."

STORAGE_KEY=$(az storage account keys list \
    --account-name "$STORAGE_NAME" \
    --resource-group "$RG_NAME" \
    --query "[0].value" \
    --output tsv)

TABLES=("MigrationTargets" "BatchHistory" "AuditLog" "SSOAppStatus")

for TABLE in "${TABLES[@]}"; do
    az storage table create \
        --name "$TABLE" \
        --account-name "$STORAGE_NAME" \
        --account-key "$STORAGE_KEY" \
        --output none
    echo "      Created: $TABLE"
done
echo "Done."
echo ""

# ======================================================================================
# [5/8] Deploy Logic App from ARM template
# ======================================================================================

echo "[5/8] Deploying Logic App: $LOGIC_APP_NAME..."
DEPLOY_OUTPUT=$(az deployment group create \
    --resource-group "$RG_NAME" \
    --template-file "$ARM_TEMPLATE" \
    --parameters \
        subscriptionId="$SUBSCRIPTION_ID" \
        aaResourceGroup="$AA_RESOURCE_GROUP" \
        aaName="$AA_NAME" \
        storageAccountName="$STORAGE_NAME" \
        hybridWorkerGroup="$HYBRID_WORKER_GROUP" \
        runbookName="$RUNBOOK_NAME" \
        location="$LOCATION" \
        maxBatchSize="$MAX_BATCH_SIZE" \
    --query "properties.outputs" \
    --output json)

echo "Done."
echo ""

# ======================================================================================
# [6/8] Get Logic App managed identity principal ID
# ======================================================================================

echo "[6/8] Retrieving Logic App managed identity..."
PRINCIPAL_ID=$(az logic workflow show \
    --name "$LOGIC_APP_NAME" \
    --resource-group "$RG_NAME" \
    --query "identity.principalId" \
    --output tsv)

echo "Principal ID: $PRINCIPAL_ID"
echo ""

# ======================================================================================
# [7/8] Assign RBAC roles to the Logic App's managed identity
# ======================================================================================

echo "[7/8] Assigning RBAC roles..."

# Role 1: Automation Operator on the Automation Account
#          Allows the Logic App to start runbook jobs and read job output
AA_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$AA_RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AA_NAME"

echo "Assigning 'Automation Operator' on $AA_NAME..."
az role assignment create \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Automation Operator" \
    --scope "$AA_RESOURCE_ID" \
    --output none 2>/dev/null || echo "(Assignment may already exist — OK)"

# Role 2: Automation Job Operator on the Automation Account
#          Allows the Logic App to read job status and output streams
echo "Assigning 'Automation Job Operator' on $AA_NAME..."
az role assignment create \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Automation Job Operator" \
    --scope "$AA_RESOURCE_ID" \
    --output none 2>/dev/null || echo "(Assignment may already exist — OK)"

# Role 3: Storage Table Data Contributor on the Storage Account
#          Allows the Logic App to read/write table entities
STORAGE_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME"

echo "      Assigning 'Storage Table Data Contributor' on $STORAGE_NAME..."
az role assignment create \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Table Data Contributor" \
    --scope "$STORAGE_RESOURCE_ID" \
    --output none 2>/dev/null || echo "(Assignment may already exist — OK)"

echo "Done."
echo ""

# ======================================================================================
# [8/8] Retrieve the Logic App HTTP trigger URL
# ======================================================================================

echo "[8/8] Retrieving Logic App trigger URL..."
TRIGGER_URL=$(az rest \
    --method POST \
    --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Logic/workflows/$LOGIC_APP_NAME/triggers/When_a_HTTP_request_is_received/listCallbackUrl?api-version=2016-06-01" \
    --query "value" \
    --output tsv 2>/dev/null || echo "UNAVAILABLE — retrieve manually from the Logic App designer")

echo ""
echo "========================================================================"
echo "  DEPLOYMENT COMPLETE"
echo "========================================================================"
echo ""
echo "  Resource Group     : $RG_NAME"
echo "  Storage Account    : $STORAGE_NAME"
echo "      Tables         : MigrationTargets, BatchHistory, AuditLog, SSOAppStatus"
echo "  Logic App          : $LOGIC_APP_NAME"
echo "      Principal ID   : $PRINCIPAL_ID"
echo ""
echo "  RBAC Assignments:"
echo "      Automation Operator       -> $AA_NAME"
echo "      Automation Job Operator   -> $AA_NAME"
echo "      Storage Table Data Contr. -> $STORAGE_NAME"
echo ""
echo "  Trigger URL:"
echo "      $TRIGGER_URL"
echo ""
echo "========================================================================"
echo "  NEXT STEPS"
echo "========================================================================"
echo ""
echo "  1. RBAC propagation takes 5-10 minutes. Wait before testing."
echo "  2. Test the Logic App with a curl POST (DryRun):"
echo ""
echo '     curl -X POST "<TRIGGER_URL>" \'
echo '       -H "Content-Type: application/json" \'
echo '       -d '"'"'{"targetUsers":["ExampleUser"],"dryRun":true,"initiator":"user"}'"'"''
echo ""
echo "  3. Check the Logic App run history in the Azure Portal."
echo "  4. Inspect Table Storage for BatchHistory and AuditLog entries."
echo "  5. Gather Logic App Trigger URL for use in Deploy-SWA.sh."
echo ""
echo "========================================================================"
echo ""
