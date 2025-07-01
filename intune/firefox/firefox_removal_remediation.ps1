$logPath = "C:\tmp\FirefoxUninstall.log"
if (!(Test-Path "C:\tmp")) { New-Item -Path "C:\tmp" -ItemType Directory -Force }
Set-Content -Path $logPath -Value "Firefox Uninstall Log - $(Get-Date)"

# Uninstall via helper.exe
$paths = @(
    "$env:ProgramFiles\Mozilla Firefox\uninstall\helper.exe",
    "$env:ProgramFiles(x86)\Mozilla Firefox\uninstall\helper.exe"
)
foreach ($exe in $paths) {
    if (Test-Path $exe) {
        Start-Process -FilePath $exe -ArgumentList "/S" -Wait -WindowStyle Hidden
        Add-Content -Path $logPath -Value "Uninstalled via helper: $exe"
    }
}

# WMI uninstall
Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE '%Firefox%'" | ForEach-Object {
    $_.Uninstall()
    Add-Content -Path $logPath -Value "Uninstalled via WMI: $($_.Name)"
}

# Registry cleanup
$regPaths = @(
    "HKLM:\Software\Mozilla",
    "HKLM:\Software\WOW6432Node\Mozilla",
    "HKCU:\Software\Mozilla"
)
foreach ($path in $regPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Add-Content -Path $logPath -Value "Removed registry key: $path"
    }
}

# Uninstall registry keys
$uninstallKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($key in $uninstallKeys) {
    Get-ChildItem $key -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $displayName = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName
            if ($displayName -like "*Firefox*") {
                Remove-Item -Path $_.PSPath -Recurse -Force
                Add-Content -Path $logPath -Value "Removed uninstall registry key: $($_.PSChildName)"
            }
        } catch {}
    }
}

# Scheduled tasks
Get-ScheduledTask | Where-Object {$_.TaskName -like "*Firefox*"} | ForEach-Object {
    Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false
    Add-Content -Path $logPath -Value "Removed scheduled task: $($_.TaskName)"
}

# User data
$paths = @(
    "$env:APPDATA\Mozilla",
    "$env:LOCALAPPDATA\Mozilla"
)
foreach ($path in $paths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Add-Content -Path $logPath -Value "Removed user data: $path"
    }
}

# Stop and remove Mozilla Maintenance Service
$serviceName = "MozillaMaintenance"
if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    try {
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        sc.exe delete $serviceName | Out-Null
        Add-Content -Path $logPath -Value "Stopped and deleted service: $serviceName"
    } catch {
        Add-Content -Path $logPath -Value "Failed to remove service: $serviceName - $($_.Exception.Message)"
    }
}

# Remove service folder
$maintenancePath = "$env:ProgramFiles\Mozilla Maintenance Service"
if (Test-Path $maintenancePath) {
    Remove-Item -Path $maintenancePath -Recurse -Force -ErrorAction SilentlyContinue
    Add-Content -Path $logPath -Value "Removed Mozilla Maintenance Service folder: $maintenancePath"
}

# Remove uninstall registry key
$maintenanceReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MozillaMaintenanceService"
if (Test-Path $maintenanceReg) {
    Remove-Item -Path $maintenanceReg -Recurse -Force -ErrorAction SilentlyContinue
    Add-Content -Path $logPath -Value "Removed Maintenance Service uninstall registry key"
}

# Intune inventory cache
$inventoryPath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Inventories"
if (Test-Path $inventoryPath) {
    Remove-Item -Path $inventoryPath -Recurse -Force -ErrorAction SilentlyContinue
    Add-Content -Path $logPath -Value "Cleared Intune inventory cache"
}

# Restart Intune Management Extension
Restart-Service -Name "IntuneManagementExtension" -Force
Add-Content -Path $logPath -Value "Restarted Intune Management Extension"

exit 0
