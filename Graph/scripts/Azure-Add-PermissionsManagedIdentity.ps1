# THIS IS NOT MY SCRIPT
# I can't remember where I found this
# If you know who wrote this please let me know so I can at least credit them
# this script is related to the doc "Intune - Set Primary Users - Azure runbook notes.md"

#Requires -Modules "Az.Accounts", "Az.Resources", "Microsoft.Graph.Applications"
[CmdletBinding()]
param (
    [Parameter()]
    [string]$AutomationAccountName = "Intune-PrimaryUserManager",

    [Parameter()]
    [string]$Tenant = "put-your-tenant-id-here",

    [Parameter()]
    [string]$Subscription = "put-your-azure-subscription-here"
)

$GRAPH_APP_ID = "00000003-0000-0000-c000-000000000000"

Connect-AzAccount -TenantId $Tenant -Subscription $Subscription  | Out-Null
Connect-MgGraph -TenantId $Tenant -Scopes "AppRoleAssignment.ReadWrite.All", "Application.Read.All" -NoWelcome

Write-Host "AZ context"
Get-AzContext | Format-List
Write-Host "MG context"
Get-MgContext | Format-List

$GraphPermissions = "DeviceManagementManagedDevices.Read.All", "DeviceManagementManagedDevices.ReadWrite.All", "AuditLog.Read.All", "User.Read.All"
$AutomationMSI = (Get-AzADServicePrincipal -Filter "displayName eq '$AutomationAccountName'")
Write-Host "Assigning permissions to $AutomationAccountName ($($AutomationMSI.Id))"

$GraphServicePrincipal = Get-AzADServicePrincipal -Filter "appId eq '$GRAPH_APP_ID'"

# I'm adding an output here because I keep running into issues with app roles - squf
Write-Host "Available roles:" 
$GraphServicePrincipal.AppRole | ForEach-Object { Write-Host $_.Value }


$GraphAppRoles = $GraphServicePrincipal.AppRole | Where-Object {$_.Value -in $GraphPermissions -and $_.AllowedMemberType -contains "Application"}

if($GraphAppRoles.Count -ne $GraphPermissions.Count)
{
    Write-Warning "App roles found: $($GraphAppRoles)"
    throw "Some App Roles are not found on Graph API service principal"
}

foreach ($AppRole in $GraphAppRoles) {
    Write-Host "Assigning $($AppRole.Value) to $($AutomationMSI.DisplayName)"
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $AutomationMSI.Id -PrincipalId $AutomationMSI.Id -ResourceId $GraphServicePrincipal.Id -AppRoleId $AppRole.Id | Out-Null
}
