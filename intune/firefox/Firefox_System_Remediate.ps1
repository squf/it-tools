# remediation script - run as system
$ErrorActionPreference = 'SilentlyContinue'
$logPath = "C:\tmp\FirefoxUninstall.log"

# create tmp folder if needed and append to log
if (!(Test-Path "C:\tmp")) { New-Item -Path "C:\tmp" -ItemType Directory -Force }
Add-Content -Path $logPath -Value "`n`nFirefox System-Context Uninstall Log - $(Get-Date)"

# 1. stop and delete the mozilla maintenance service
$serviceName = "MozillaMaintenance"
Add-Content -Path $logPath -Value "Checking for $serviceName service..."
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service) {
    if ($service.Status -eq 'Running') {
        Stop-Service -Name $serviceName -Force
        Add-Content -Path $logPath -Value "Stopped $serviceName."
    }
    sc.exe delete $serviceName | Out-Null
    Add-Content -Path $logPath -Value "Deleted $serviceName service."
} else {
    Add-Content -Path $logPath -Value "Service not found."
}

# 2. find and run any system-wide uninstallers
Add-Content -Path $logPath -Value "Searching for system-based uninstallers..."
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($path in $uninstallPaths) {
    Get-ChildItem -Path $path | Get-ItemProperty | Where-Object { $_.DisplayName -like 'Mozilla Firefox*' } | ForEach-Object {
        if ($_.UninstallString) {
            $uninstallString = $_.UninstallString
            Add-Content -Path $logPath -Value "Found system uninstall string: $uninstallString"
            
            $command = $uninstallString.Split(' ') | Select-Object -First 1
            $args = "/S"

            Add-Content -Path $logPath -Value "Executing: $command $args"
            Start-Process -FilePath $command -ArgumentList $args -Wait -WindowStyle Hidden
            Add-Content -Path $logPath -Value "System-wide Firefox uninstall command completed."
        }
    }
}

# 3. forcefully remove leftover system folders and registry keys
Add-Content -Path $logPath -Value "Performing final cleanup of system locations..."
$foldersToRemove = @(
    "$env:ProgramFiles\Mozilla Firefox",
    "$env:ProgramFiles(x86)\Mozilla Firefox",
    "$env:ProgramFiles\Mozilla Maintenance Service",
    "$env:ProgramFiles(x86)\Mozilla Maintenance Service"
)
foreach ($folder in $foldersToRemove) {
    if (Test-Path $folder) {
        Remove-Item -Path $folder -Recurse -Force
        Add-Content -Path $logPath -Value "Removed folder: $folder"
    }
}

$regPathsToRemove = @(
    "HKLM:\Software\Mozilla",
    "HKLM:\Software\WOW6432Node\Mozilla"
)
foreach ($regPath in $regPathsToRemove) {
    if (Test-Path $regPath) {
        Remove-Item -Path $regPath -Recurse -Force
        Add-Content -Path $logPath -Value "Removed registry key: $regPath"
    }
}

# 4. ensure all uninstall keys are gone
foreach ($path in $uninstallPaths) {
    Get-ChildItem -Path $path | Where-Object { (Get-ItemProperty $_.PSPath).DisplayName -like 'Mozilla*' } | ForEach-Object {
        Add-Content -Path $logPath -Value "Removing stale uninstall key: $($_.PSPath)"
        Remove-Item -Path $_.PSPath -Recurse -Force
    }
}

# 5. restart intune service to force inventory update
Add-Content -Path $logPath -Value "Restarting Intune Management Extension service..."
Restart-Service -Name "IntuneManagementExtension" -Force
Add-Content -Path $logPath -Value "System-level cleanup finished."

exit 0
