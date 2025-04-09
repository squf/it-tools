# this script is just looking for Windows devices not meeting compliance, then outputs a .csv to the working directory the script is run from
# run complianceCheckCleanup.py after to clean up the output from this script

$AllWindowsDevices            = Get-MgBetaDeviceManagementManagedDevice -Filter "OperatingSystem eq 'Windows'" -All 
$AllWindowsCompliancySettings = Get-MgBetaDeviceManagementDeviceCompliancePolicySettingStateSummary | Where-Object { $_.PlatformType -like "*windows10*" -or $_.PlatformType -like "All" }

$Export = Foreach ($setting in $AllWindowsCompliancySettings) {
                
    Write-Verbose "Checking: $($($setting.SettingName -split "\.")[1])" -verbose
    Get-MgBetaDeviceManagementDeviceCompliancePolicySettingStateSummaryDeviceComplianceSettingState -filter "PlatformType eq 'WindowsRT'" -DeviceCompliancePolicySettingStateSummaryId $setting.id -all
}

$CompleteExport = Foreach ($Device in $Export) {
                        
    $Device | Foreach { 
                    
        [PScustomObject][Ordered]@{
                        
            DeviceName         = $_.devicename
            DeviceID           = $_.deviceid
            DeviceModel        = $_.devicemodel
            DeviceSerialNumber = ($AllWindowsDevices | Where-Object { $_.devicename -eq $Device.devicename }).serialnumber     -join ";"
            OsVersion          = ($AllWindowsDevices | Where-Object { $_.devicename -eq $Device.devicename }).osversion        -join ";"
            SettingName        = ($_.SettingName -split "\.")[1]
            UserName           = $_.username
            UserPrincipalName  = $_.userPrincipalname
            State              = $_.state
            EnrolledDateTime   = ($AllWindowsDevices | Where-Object { $_.devicename -eq $Device.devicename }).enrolledDateTime -join ";"
            LastSyncDateTime   = ($AllWindowsDevices | Where-Object { $_.devicename -eq $Device.devicename }).lastSyncDateTime -join ";"
            OverallCompliancy  = ($AllWindowsDevices | Where-Object { $_.devicename -eq $Device.devicename }).complianceState  -join ";"
        }          
    }                
}

$CompleteExport 
