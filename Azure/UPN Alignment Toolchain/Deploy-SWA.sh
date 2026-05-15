#!/bin/bash
# ======================================================================================
# Deploy-SWA.sh — UPN Control Center (Static Web App)
#
# Run from Azure Cloud Shell (Bash)
#
# Author:  squf — Systems Administrator
# Github: https://github.com/squf/it-tools/Azure/UPN%20Alignment%20Toolchain
# ======================================================================================
set -euo pipefail

SUBSCRIPTION_ID="[enter subscription ID here]"
RG_NAME="[enter preferred resource group name here, e.g. rg-upn-toolchain]"
SWA_NAME="[enter preferred unique SWA name here, e.g. upn-control-center]"
STORAGE_NAME="[enter preferred unique storage account name here, e.g. stupntoolchain]"
LOCATION="[pick region close to you, e.g. eastus2]"
LOGIC_APP_TRIGGER_URL="[gathered from Logic App resource after deployment]"

echo ""
echo "========================================================================"
echo "  UPN Control Center — Static Web App Deployment"
echo "========================================================================"
echo ""

# [1/7] Set subscription
echo "[1/7] Setting subscription..."
az account set --subscription "$SUBSCRIPTION_ID"
echo "Done."
echo ""

# [2/7] Create Static Web App
echo "[2/7] Creating Static Web App: $SWA_NAME..."
az staticwebapp create \
    --name "$SWA_NAME" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    --sku Free \
    --tags Project="UPN-Alignment" CostCenter="IT" ManagedBy="User" \
    --output none 2>/dev/null || echo "(May already exist — OK)"
echo "Done."
echo ""

# [3/7] Configure app settings
echo "[3/7] Configuring app settings..."
STORAGE_CONN=$(az storage account show-connection-string \
    --name "$STORAGE_NAME" \
    --resource-group "$RG_NAME" \
    --query "connectionString" \
    --output tsv)

az staticwebapp appsettings set \
    --name "$SWA_NAME" \
    --resource-group "$RG_NAME" \
    --setting-names \
        "STORAGE_CONNECTION_STRING=$STORAGE_CONN" \
        "LOGIC_APP_TRIGGER_URL=$LOGIC_APP_TRIGGER_URL" \
    --output none
echo "Done."
echo ""

# [4/7] Seed SSO app data
echo "[4/7] Seeding SSO app data..."
STORAGE_KEY=$(az storage account keys list \
    --account-name "$STORAGE_NAME" \
    --resource-group "$RG_NAME" \
    --query "[0].value" --output tsv)

SSO_APPS=(
    # example apps, replace with what's relevant for your org — format is:
    # "RowKey|AppName|AuthMethod|UserAccountBasis|RiskLevel"
    "BambooHR|BambooHR SAML|saml|user.userprincipalname|HIGH"
    "Box|Box SAML|saml|user.userprincipalname|HIGH"
    "DocuSign|DocuSign SAML|saml|user.userprincipalname|HIGH"
    "GitHub|GitHub OIDC|oidc|user.userprincipalname|HIGH"
    "GoToMeeting|GoToMeeting SAML|saml|user.userprincipalname|HIGH"
    "Microsoft 365|Microsoft 365 SAML|saml|user.userprincipalname|HIGH"
    "Okta|Okta SAML|saml|user.userprincipalname|HIGH"
    "OneLogin|OneLogin SAML|saml|user.userprincipalname|HIGH"
    "Salesforce|Salesforce SAML|saml|user.userprincipalname|HIGH"
    "ServiceNow|ServiceNow SAML|saml|user.userprincipalname|HIGH"
    "Smartsheet|Smartsheet SAML|saml|user.userprincipalname|HIGH"
    "Snowflake|Snowflake OIDC|oidc|user.userprincipalname|HIGH"
    "Splunk|Splunk SAML|saml|user.userprincipalname|HIGH"
    "Workday|Workday SAML|saml|user.userprincipalname|HIGH"

)

for entry in "${SSO_APPS[@]}"; do
  IFS='|' read -r key name auth basis risk <<< "$entry"
  az storage entity insert \
      --table-name SSOAppStatus \
      --account-name "$STORAGE_NAME" \
      --account-key "$STORAGE_KEY" \
      --if-exists merge \
      --entity PartitionKey=app RowKey="$key" \
          AppName="$name" AuthMethod="$auth" \
          UserAccountBasis="$basis" RiskLevel="$risk" \
          VendorContacted=false PreRenameDone=false ClearedForCutover=false \
      --output none 2>/dev/null
  echo "      Seeded: $name"
done
echo "Done."
echo ""

# [5/7] Install API dependencies
echo "[5/7] Installing API dependencies..."
cd api && npm install --production --silent 2>/dev/null && cd ..
echo "Done."
echo ""

# [6/7] Deploy
echo "[6/7] Deploying Static Web App..."
DEPLOY_TOKEN=$(az staticwebapp secrets list \
    --name "$SWA_NAME" \
    --resource-group "$RG_NAME" \
    --query "properties.apiKey" \
    --output tsv)

npx --yes @azure/static-web-apps-cli deploy \
    --app-location app \
    --api-location api \
    --deployment-token "$DEPLOY_TOKEN" \
    --env default 2>&1 | tail -5
echo "Done."
echo ""

# [7/7] Summary
HOSTNAME=$(az staticwebapp show \
    --name "$SWA_NAME" \
    --resource-group "$RG_NAME" \
    --query "defaultHostname" \
    --output tsv)

echo "========================================================================"
echo "  DEPLOYMENT COMPLETE"
echo "========================================================================"
echo ""
echo "  Static Web App : $SWA_NAME"
echo "  URL            : https://$HOSTNAME"
echo ""
echo "========================================================================"
echo "  NEXT STEPS — Entra Auth & Role Assignment"
echo "========================================================================"
echo ""
echo "  1. In the Azure Portal, go to the SWA resource → Settings → Role management"
echo "  2. Invite users/groups to roles:"
echo "       SG-UPN-Toolchain-Admins  → admin"
echo "       SG-UPN-Toolchain-Viewers → viewer"
echo ""
echo "  3. Alternatively, use the Entra ID app registration method:"
echo "       - Go to Entra → App registrations → find the SWA app"
echo "       - Under 'App roles', create 'admin' and 'viewer' roles"
echo "       - Under 'Enterprise applications', assign your security groups"
echo ""
echo "  4. Test by navigating to: https://$HOSTNAME"
echo ""
echo "========================================================================"
