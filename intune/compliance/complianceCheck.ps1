<#############################################################################################

Intune - Device Compliance Report
Version: 1.2
Modified to include detailed compliance failure reasons
Date: 04/15/2025
Author(s): Curtis Cannon (traversecloud.co.uk), squf, DeepSeek LLM
More: https://traversecloud.co.uk/generate-a-device-compliance-report-using-powershell/
About: Yeah I took this guy's powershell script and ran it through deepseek to make some tweaks

#############################################################################################>

# Get the directory where the script is located
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportName = "Intune_Device_Compliance_$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$ReportPath = Join-Path -Path $ScriptPath -ChildPath $ReportName

# Check for required PowerShell Module
$GraphCheck = Get-Module Microsoft.Graph -ListAvailable
If ($GraphCheck -eq $null) {
    Write-Host -ForegroundColor Red "MS Graph Powershell Module Not Installed!"
    Write-Host ""
    Write-Host "MS Graph Powershell module is required to run this script"
    Write-Host "Please use the command [Install-Module Microsoft.Graph] to install"
    Write-Host ""
    Pause
    Exit
}

# Function to get detailed compliance failure reasons
function Get-DetailedComplianceFailure {
    param (
        [string]$DeviceID
    )
   
    try {
        $complianceStates = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$DeviceID')/deviceCompliancePolicyStates" -ErrorAction Stop
       
        $failureDetails = @()
       
        foreach ($policyState in $complianceStates.value) {
            if ($policyState.state -ne "compliant") {
                # Get policy name
                $policyName = $policyState.displayName
               
                # Get setting states if available
                if ($policyState.settingStates) {
                    foreach ($settingState in $policyState.settingStates) {
                        if ($settingState.state -ne "compliant") {
                            $failureDetails += "$policyName | Setting: $($settingState.settingName) | State: $($settingState.state) | Error: $($settingState.errorCode)"
                        }
                    }
                } else {
                    # If no setting states, just report the policy non-compliance
                    $failureDetails += "$policyName | State: $($policyState.state)"
                }
            }
        }
       
        if ($failureDetails.Count -gt 0) {
            return $failureDetails -join " | "
        } else {
            return "Compliant"
        }
    }
    catch {
        return "Error retrieving compliance data: $($_.Exception.Message)"
    }
}

# Clear Results Array
$Results = @()

# Connect to Graph with required delegated permissions
Connect-MgGraph -Scopes "Device.Read.All, DeviceManagementManagedDevices.Read.All, DeviceManagementConfiguration.Read.All" -NoWelcome

# Collect a list of all managed device IDs
Write-Host "Collecting device list..."
$AllDevices = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/devices?$filter=managementType ne null&$count=true&$select=id' -Headers @{ConsistencyLevel = "eventual"}
$DeviceIDs = $AllDevices.value.ID

# Check and collect data from additional pages
Do {
    if ($AllDevices."@odata.nextlink" -ne $null) {
        $AllDevices = Invoke-MgGraphRequest -Method GET -Uri $AllDevices."@odata.nextlink"
        $DeviceIDs += $AllDevices.value.ID
    }
} Until ($AllDevices."@odata.nextlink" -eq $null)

Write-Host "Found $($DeviceIDs.Count) devices to process..."

# Collect information for each listed device
$DeviceCount = 0
foreach ($DeviceID in $DeviceIDs) {
    $DeviceCount ++
   
    # Get basic device info
    $Device = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/devices/$($DeviceID)?`$select=id,displayName,operatingSystem,operatingSystemVersion,isCompliant,manufacturer,model,createdDateTime,managementType"
    Write-Progress -PercentComplete ($DeviceCount/$DeviceIDs.count*100) -Status "Processing Devices" -Activity "($DeviceCount of $($DeviceIDs.count)) Currently on $($Device.displayname)"
   
    # Get detailed compliance status
    $complianceDetails = if ($Device.isCompliant -eq $false) {
        Get-DetailedComplianceFailure -DeviceID $DeviceID
    } else {
        "Compliant"
    }
   
    # Get owner information
    $owner = try {
        $ownerInfo = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/devices/$($DeviceID)/registeredOwners?`$select=userPrincipalName" -ErrorAction SilentlyContinue
        if ($ownerInfo.value -and $ownerInfo.value.userPrincipalName) {
            $ownerInfo.value.userPrincipalName
        } else {
            "No owner"
        }
    } catch {
        "Error retrieving owner"
    }
   
    $Results += [PSCustomObject]@{
        "Device Name"          = $Device.displayname
        "Compliant"           = $Device.isCompliant
        "Compliance Details"   = $complianceDetails
        "OS"                  = $Device.operatingSystem
        "OS Version"          = $Device.operatingSystemVersion
        "Owner"               = $owner
        "Model"               = $Device.model
        "Created"             = ($Device.createdDateTime).ToString('dd/MM/yyyy HH:mm')
        "Management Type"     = $Device.managementType
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph

# Save results to csv
$Results | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8

Write-Host "Report generated successfully at: $ReportPath"
Write-Host "Opening report location..."
Start-Process (Split-Path -Path $ReportPath -Parent)
