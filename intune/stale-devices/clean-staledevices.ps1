# squf's stale device clean-up script, designed to work as an Azure Runbook or scheduled task / other automated fashion
# test it with the -WhatIf parameter first to ensure its working as expected before you set it up for automated running
# works with a registered Entra Enterprise App that uses a CertThumbprint, so if you're using client secrets or some other way of doing app authentication you'd need to adjust the Connect-MgGraph parameters and their preceding variables
# this requires the app you're using for authentication to have the "DeviceManagementManagedDevices.ReadWrite.All" & "Directory.Read.All" permissions to work

param(
    [Parameter(Mandatory = $true)]
    [int]$DaysStale,

    [switch]$WhatIf
)

$AppId = "<ENTER-AppID-HERE"
$CertificateThumbprint = "<ENTER-CertThumbprint-HERE>"
$TenantId = "<ENTER-TenantID-HERE>"

Connect-MgGraph -ClientId $AppId -TenantId $TenantId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop

$devices = Get-MgDeviceManagementManagedDevice -All
# this part fetches today's date and then checks back however many days were specified in the -DaysStale parameter
$now = Get-Date

$staleDevices = $devices | Where-Object {
    if ($_.LastSyncDateTime -eq $null) {
        $true
    } else {
        ($now - $_.LastSyncDateTime).Days -ge $DaysStale
    }
}

Write-Output "Found $($staleDevices.Count) stale devices."
# this foreach loop does the actual cleanup part (-:
foreach ($device in $staleDevices) {
    Write-Output "Processing device: $($device.DeviceName) ($($device.Id))"

    if ($WhatIf) {
        Write-Output "Would delete Intune device: $($device.Id)"
    } else {
        Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id -ErrorAction SilentlyContinue
        Write-Output "Deleted Intune device: $($device.Id)"
    }

    try {
        $entraDevice = Get-MgDevice -Filter "deviceId eq '0'" -ExpandProperty Id -ErrorAction SilentlyContinue
        if ($entraDevice) {
            if ($WhatIf) {
                Write-Output "Would delete Entra device: $($entraDevice.Id)"
            } else {
                Remove-MgDevice -DeviceId $entraDevice.Id -ErrorAction SilentlyContinue
                Write-Output "Deleted Entra device: $($entraDevice.Id)"
            }
        }
    } catch {
        Write-Warning "Failed to find or delete Entra device for: $($device.DeviceName)"
    }
}

Disconnect-MgGraph
