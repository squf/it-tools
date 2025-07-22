# FF_nuke_rem.ps1 - A comprehensive script to completely remove Firefox and related components.
$ErrorActionPreference = 'SilentlyContinue'
$logPath = "C:\tmp\FirefoxNuke.log"
if (!(Test-Path "C:\tmp")) { New-Item -Path "C:\tmp" -ItemType Directory -Force }
Function Write-Log { param ([string]$Message) Add-Content -Path $logPath -Value "($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) - $Message" }
Set-Content -Path $logPath -Value "--- Firefox Nuke Remediation Started ---"
Write-Log "Stopping Firefox processes..."
Get-Process -Name 'firefox', 'maintenanceservice', 'crashreporter' | Stop-Process -Force
Write-Log "Searching for uninstall strings in the registry..."
$uninstallKeys = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' | Get-ItemProperty
$uninstallStrings = $uninstallKeys | Where-Object { $_.DisplayName -like 'Mozilla Firefox*' -or $_.DisplayName -like 'Mozilla Maintenance Service*' } | Select-Object -ExpandProperty UninstallString

if ($uninstallStrings) {
    foreach ($string in $uninstallStrings) {
        Write-Log "Found UninstallString: $string"
        $uninstallerPath = $string -replace '"', '' -replace '/.+$', ''
        $uninstallerArgs = "/S"

        if (Test-Path $uninstallerPath) {
            Write-Log "Executing: $uninstallerPath $uninstallerArgs"
            Start-Process -FilePath $uninstallerPath -ArgumentList $uninstallerArgs -Wait -NoNewWindow
        } else {
            Write-Log "Warning: Uninstaller path not found: $uninstallerPath"
        }
    }
} else {
    Write-Log "No standard Firefox uninstall entries found. Proceeding with manual removal."
}
Write-Log "Beginning forceful removal of services and files..."
$service = Get-Service -Name 'MozillaMaintenance'
if ($service) {
    Write-Log "Stopping and removing MozillaMaintenance service."
    Stop-Service -Name $service.Name -Force
    sc.exe delete $service.Name
}
$foldersToRemove = @(
    "$env:ProgramFiles\Mozilla Firefox",
    "$env:ProgramFiles(x86)\Mozilla Firefox",
    "$env:ProgramFiles(x86)\Mozilla Maintenance Service"
)
foreach ($folder in $foldersToRemove) {
    if (Test-Path $folder) {
        Write-Log "Deleting folder: $folder"
        Remove-Item -Path $folder -Recurse -Force
    }
}
Write-Log "Deleting user profile data and shortcuts..."
$userProfiles = Get-ChildItem -Path "C:\Users" -Directory
foreach ($profile in $userProfiles) {
    $userPath = $profile.FullName
    $foldersToRemove_User = @(
        "$userPath\AppData\Roaming\Mozilla",
        "$userPath\AppData\Local\Mozilla",
        "$userPath\AppData\Local\Microsoft\Windows\WER\ReportArchive\*firefox*",
        "$userPath\AppData\Local\Microsoft\Windows\WER\ReportQueue\*firefox*"
    )
    $shortcutsToRemove_User = @(
        "$userPath\Desktop\Firefox.lnk",
        "$userPath\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Firefox.lnk"
    )
    foreach ($folder in $foldersToRemove_User) {
        if (Test-Path $folder) {
            Write-Log "Deleting user folder: $folder"
            Remove-Item $folder -Recurse -Force
        }
    }
    foreach ($shortcut in $shortcutsToRemove_User) {
        if (Test-Path $shortcut) {
            Write-Log "Deleting user shortcut: $shortcut"
            Remove-Item $shortcut -Force
        }
    }
}
Write-Log "Cleaning core registry keys..."
$registryKeysToRemove = @(
    'HKLM:\SOFTWARE\Mozilla',
    'HKLM:\SOFTWARE\WOW6432Node\Mozilla'
)
foreach ($key in $registryKeysToRemove) {
    if (Test-Path $key) {
        Write-Log "Deleting registry key: $key"
        Remove-Item -Path $key -Recurse -Force
    }
}

Write-Log "--- Firefox Nuke Remediation Finished ---"
exit 0
