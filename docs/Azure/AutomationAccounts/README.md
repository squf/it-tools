This document outlines some of the issues I ran into when setting up an Azure Automation Account / Runbook, to ensure all of our Shared Mailboxes & Resource objects in Exchange Online were being added to specific Entra groups.

This is intended as a general overview & guideline for my very specific task, and you will need to make significant alterations to these steps to do different tasks based on your use-case. 

However, there are some helpful things covered here-in, so I wanted to store this documentation on GitHub.

---

# 🚀 Guide to Setting Up an Automation Runbook with Managed Identity

This guide details the steps to create an Azure Automation Runbook that can manage Entra ID groups and read from Exchange Online using a secure, credential-less **Managed Identity**.

### 📋 Table of Contents

1. [Create the Automation Account & Enable Identity](https://learn.microsoft.com/en-us/azure/automation/enable-managed-identity-for-automation)
    
2. [Assign API Permissions](https://techcommunity.microsoft.com/blog/integrationsonazureblog/grant-graph-api-permission-to-azure-automation-system-assigned-managed-identity/4278846)
    
3. [Assign Exchange Admin Role](https://learn.microsoft.com/en-us/powershell/exchange/connect-exo-powershell-managed-identity?view=exchange-ps#step-5-assign-microsoft-entra-roles-to-the-managed-identity)
    
4. [Configure Runbook Modules](https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/3151)
    
5. [Create the Runbook & Add Script](https://learn.microsoft.com/en-us/azure/automation/learn/automation-tutorial-runbook-textual)


---

### 1. Create the Automation Account & Enable Identity ⚙️

First, create the Azure Automation Account and enable its System-Assigned Managed Identity. This creates the Service Principal in Entra ID that we will grant permissions to.

1. In the Azure portal, create a new **Automation Account**.
    
2. Navigate to your new Automation Account.
    
3. Under **Account Settings**, select **Identity**.
    
4. Set the status of the **System assigned** identity to **On** and click **Save**.
    
5. Copy the **Object (principal) ID** and **Application (client) ID** from this page for use in the following steps.
    

---

### 2. Assign API Permissions 🔐

The necessary API permissions for your Azure Automation account will vary depending on what you are doing with your end script. In this example, I set-up an Automation Account to manage a runbook which checks: Group Membership in Entra, Exchange Online Shared Mailboxes & Resources, then add the Shared Mailboxes & Resources to their respective Entra Groups if they were missing as members. **This is only an example and should not be followed exactly for your case!**

The Managed Identity needs API permissions to manage group members and connect to Exchange. We will assign these programmatically using a "cloning" method, as this proved to be the most reliable way in my experience.

#### Step 2.1: Create a Temporary App Registration

1. In the Entra admin center, go to **Identity > Applications > App registrations**.
    
2. Click **+ New registration** and name it `Temp Permission Holder`.
    
3. Go to the new app's **API permissions** blade.
    
4. Click **+ Add a permission** > **Microsoft Graph** > **Application permissions**.
    
5. Add `GroupMember.ReadWrite.All`.
    
6. Click **+ Add a permission** > **APIs my organization uses** > search for and select **Office 365 Exchange Online** > **Application permissions**.
    
7. Add `Exchange.ManageAsApp`.
    
8. Click the **Grant admin consent for...** button to approve both permissions.
    

#### Step 2.2: Run the "Cloning" Script

Run this PowerShell script on your local machine to copy the permissions from the temporary app to your Managed Identity. Be sure to update the necessary variables with your appropriate APPID and OBJECTID. Additionally, do NOT remove the `Connect-MgGraph` call as we need the appropriate scope permissions for this to work.


```PowerShell
# 1. Connect to Graph with necessary scopes
Connect-MgGraph -Scopes "Application.Read.All", "AppRoleAssignment.ReadWrite.All"

# --- CONFIGURATION ---
# The Application (client) ID of your "Temp Permission Holder" app
$sourceAppClientId = "PASTE_TEMP_APP_CLIENT_ID_HERE" 

# The Object ID of your Automation Account's Managed Identity
$targetManagedIdentityObjectId = "PASTE_MANAGED_IDENTITY_OBJECT_ID_HERE" 
# --- END CONFIGURATION ---

# Find the service principal for the Temp App using its unique App ID
$sourceSP = Get-MgServicePrincipal -Filter "appId eq '$sourceAppClientId'"
If (-not $sourceSP) { Write-Error "Could not find the Service Principal for the temp app."; return }

# --- Clone GroupMember.ReadWrite.All permission ---
$groupMemberPermissionId = '[EXAMPLE-PERMID]'
$sourceGrant = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sourceSP.Id | Where-Object { $_.AppRoleID -eq $groupMemberPermissionId }
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $targetManagedIdentityObjectId -PrincipalId $targetManagedIdentityObjectId -ResourceId $sourceGrant.ResourceId -AppRoleId $sourceGrant.AppRoleId
Write-Host "Cloned GroupMember.ReadWrite.All" -ForegroundColor Green

# --- Clone Exchange.ManageAsApp permission ---
$exchangePermissionId = '[EXAMPLE-PERMID]'
$sourceGrant = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sourceSP.Id | Where-Object { $_.AppRoleID -eq $exchangePermissionId }
New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $targetManagedIdentityObjectId -PrincipalId $targetManagedIdentityObjectId -ResourceId $sourceGrant.ResourceId -AppRoleId $sourceGrant.AppRoleId
Write-Host "Cloned Exchange.ManageAsApp" -ForegroundColor Green

Write-Host "SUCCESS! All permissions have been assigned." -ForegroundColor Green
Disconnect-MgGraph
```

> After this is complete, you can safely **delete** the `"Temp Permission Holder"` App Registration.

---

### 3. Assign Exchange Admin Role 📧

The modern method for app-only authentication requires assigning an Entra ID role. This command grants the Managed Identity the necessary permissions to connect to Exchange Online. Again, this is only an example that I used in my particular case, this will vary with different Automation Accounts in the future depending on what you are doing, so you will likely use a different role.

1. Connect to Microsoft Graph PowerShell with role management permissions:
    
    ```PowerShell
    Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory"
    ```
    
2. Run the following script to assign the `Exchange Administrator` role:
    
    ```PowerShell
    # Get the definition for the "Exchange Administrator" role
    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Exchange Administrator'"
    
    # The Object ID of your Managed Identity
    $principalId = "PASTE_MANAGED_IDENTITY_OBJECT_ID_HERE"
    
    # Assign the role
    New-MgRoleManagementDirectoryRoleAssignment -DirectoryScopeId '/' -RoleDefinitionId $roleDefinition.Id -PrincipalId $principalId
    
    Write-Host "SUCCESS: The 'Exchange Administrator' role has been assigned." -ForegroundColor Green
    ```
    

---

### 4. Configure Runbook Modules 📚

To avoid dependency issues, you must manually upload specific, known-good versions of the required modules. Please view the linked item in the Table of Contents to view a GitHub issue for this. **At the time I made this Automation Account, PowerShell 7.2 modules available directly from the gallery were not working, this could change in the future.** In my case, the gallery was importing version **2.29.0** PowerShell modules which were not working in PowerShell 7.2 in Azure at the time, so I had to download the `nupkg` files for version **2.25.0** from PowerShellGallery and convert them to .ZIP folders, then manually upload them to Azure to work. 

This is all under the `Modules` section on your Automation Account, this controls what PowerShell modules the automation account will use for any associated runbooks under itself.

1. **Delete any existing Graph/Exchange modules** from your Automation Account for a clean slate.
    
2. **Download the `.nupkg` files** for the following specific module versions from the PowerShell Gallery:
    
    - `Microsoft.Graph.Authentication` version **2.25.0**
        
    - `Microsoft.Graph.Groups` version **2.25.0**
        
    - `ExchangeOnlineManagement` version **3.4.0**
        
3. For each downloaded `.nupkg` file:
    
    - Rename the file to match the actual module name (e.g., rename from "`exchangeonlinemanagement3.4.0.nupkg`" to "`ExchangeOnlineManagement`").
        
    - Rename the file extension from `.nupkg` to **`.zip`**.
        
    - Now you should have a .zip file matching the name of the module in question exactly (e.g., `Microsoft.Graph.Groups.zip` or `ExchangeOnlineManagement.zip`).
    
4. In the Automation Account, go to **Modules** -> **Add a module**.
    
5. Choose **Upload a module file** and upload the final `.zip` files you created, ensuring the **Runtime version** is set to **7.2**.
    

---

### 5. Create the Runbook & Add Script ✍️

This is an **example** of the final script I added as a runbook to this particular Automation Account. **This is not the script you should be using for a different task, you need to come up with your own PowerShell script for your specific use-case(s)!**

1. In your Automation Account, go to **Runbooks** and click **+ Create a runbook**.
    
2. Set the **Name**, choose **PowerShell** for the type, and **7.2** for the Runtime version.
    
3. Paste your script into the editor, run a test on it, and after the test is passing **Save** and **Publish**.
    

*Example script:*

```PowerShell
<#
.SYNOPSIS
    Synchronizes Exchange Online Shared Mailboxes and Resources into dedicated Entra ID groups.
.DESCRIPTION
    This script is designed to run in an Azure Automation Runbook using a Managed Identity.
#>

# =====================================================================================
#   0. IMPORT REQUIRED MODULES
# =====================================================================================
# Explicitly import the specific module versions uploaded to the Automation Account.
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Groups
Import-Module ExchangeOnlineManagement

# =====================================================================================
#   1. AUTHENTICATION
# =====================================================================================
try {
    Write-Output "Connecting using Managed Identity..."
    Connect-MgGraph -Identity
    Connect-ExchangeOnline -ManagedIdentity -Organization "company.onmicrosoft.com" # UPDATE THIS VALUE
    Write-Output "Successfully connected to Microsoft Graph and Exchange Online."
}
catch {
    Write-Error "Failed to connect using Managed Identity. Error: $($_.Exception.Message)"
    exit
}

# =====================================================================================
#   2. SCRIPT LOGIC
# =====================================================================================

# --- Define Group Object IDs ---
$sharedMailboxGroupId = "[EXAMPLE-GROUP-ID]"
$resourceGroupId = "[EXAMPLE-GROUP-ID]"

# --- Process Shared Mailboxes ---
Write-Output "--- Starting Shared Mailbox Sync ---"
try {
    $sharedMailboxes = Get-EXOMailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited | Select-Object ExternalDirectoryObjectId, DisplayName
    if ($null -eq $sharedMailboxes) {
        Write-Output "No shared mailboxes found."
    } else {
        Write-Output "Found $($sharedMailboxes.Count) total shared mailboxes."
        $currentSmbMembers = Get-MgGroupMember -GroupId $sharedMailboxGroupId -All | Select-Object -ExpandProperty Id
        $mailboxesToAdd = $sharedMailboxes | Where-Object { $_.ExternalDirectoryObjectId -notin $currentSmbMembers }

        if ($mailboxesToAdd.Count -eq 0) {
            Write-Output "All shared mailboxes are already in the target group."
        } else {
            Write-Output "Found $($mailboxesToAdd.Count) new shared mailboxes to add."
            foreach ($mailbox in $mailboxesToAdd) {
                try {
                    New-MgGroupMember -GroupId $sharedMailboxGroupId -DirectoryObjectId $mailbox.ExternalDirectoryObjectId
                    Write-Output "SUCCESS: Added '$($mailbox.DisplayName)' to group."
                } catch {
                    Write-Warning "FAILURE: Could not add '$($mailbox.DisplayName)'. Error: $($_.Exception.Message)"
                }
            }
        }
    }
}
catch { Write-Error "An error occurred while processing Shared Mailboxes: $($_.Exception.Message)" }
Write-Output "--- Finished Shared Mailbox Sync ---`n"

# --- Process Resources (Rooms & Equipment) ---
Write-Output "--- Starting Resource Sync ---"
try {
    $resources = Get-EXOMailbox -RecipientTypeDetails RoomMailbox, EquipmentMailbox -ResultSize Unlimited | Select-Object ExternalDirectoryObjectId, DisplayName
    if ($null -eq $resources) {
        Write-Output "No resources found."
    } else {
        Write-Output "Found $($resources.Count) total resources."
        $currentResourceMembers = Get-MgGroupMember -GroupId $resourceGroupId -All | Select-Object -ExpandProperty Id
        $resourcesToAdd = $resources | Where-Object { $_.ExternalDirectoryObjectId -notin $currentResourceMembers }

        if ($resourcesToAdd.Count -eq 0) {
            Write-Output "All resources are already in the target group."
        } else {
            Write-Output "Found $($resourcesToAdd.Count) new resources to add."
            foreach ($resource in $resourcesToAdd) {
                try {
                    New-MgGroupMember -GroupId $resourceGroupId -DirectoryObjectId $resource.ExternalDirectoryObjectId
                    Write-Output "SUCCESS: Added '$($resource.DisplayName)' to group."
                } catch {
                    Write-Warning "FAILURE: Could not add '$($resource.DisplayName)'. Error: $($_.Exception.Message)"
                }
            }
        }
    }
}
catch { Write-Error "An error occurred while processing Resources: $($_.Exception.Message)" }
Write-Output "--- Finished Resource Sync ---`n"

# =====================================================================================
#   3. DISCONNECT
# =====================================================================================
Write-Output "Script finished. Disconnecting sessions."
Disconnect-MgGraph
Disconnect-ExchangeOnline
```

* After you've successfully set-up the Automation Account, added the script & tested it, saved & published the script, you just need to go in and add a **Schedule** to it to have it run on a schedule. You have to go make a schedule first under the `Schedules` tab, then go back to the Overview page and link the runbook to the schedule you created. After that, it will continue running indefinitely in the background in Azure.
