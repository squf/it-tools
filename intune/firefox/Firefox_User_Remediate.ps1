# remediation script - run in user context
$ErrorActionPreference = 'SilentlyContinue'
$logPath = "C:\tmp\FirefoxUninstall.log"

# create/overwrite log file
if (!(Test-Path "C:\tmp")) { New-Item -Path "C:\tmp" -ItemType Directory -Force }
Set-Content -Path $logPath -Value "Firefox User-Context Uninstall Log - $(Get-Date)"

# 1. find and run the uninstaller from the user's registry
Add-Content -Path $logPath -Value "Searching for user-based Firefox uninstaller..."
$uninstallKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$firefoxApp = Get-ChildItem -Path $uninstallKey | Get-ItemProperty | Where-Object { $_.DisplayName -like 'Mozilla Firefox*' }

if ($firefoxApp.UninstallString) {
    $uninstallString = $firefoxApp.UninstallString
    Add-Content -Path $logPath -Value "Found uninstall string: $uninstallString"
    
    # ensure path is quoted and add silent switch
    $command = $uninstallString.Split(' ') | Select-Object -First 1
    $args = "/S"
    
    Add-Content -Path $logPath -Value "Executing: $command $args"
    Start-Process -FilePath $command -ArgumentList $args -Wait -WindowStyle Hidden
    Add-Content -Path $logPath -Value "Firefox uninstall command completed."
} else {
    Add-Content -Path $logPath -Value "Could not find Firefox uninstall string in HKCU."
}

# 2. kill any lingering firefox processes
Add-Content -Path $logPath -Value "Terminating any running Firefox processes..."
Get-Process -Name "firefox" -ErrorAction SilentlyContinue | Stop-Process -Force

# 3. forcefully remove leftover user folders and registry keys
Add-Content -Path $logPath -Value "Performing final cleanup of user profile..."
$foldersToRemove = @(
    "$env:APPDATA\Mozilla",
    "$env:LOCALAPPDATA\Mozilla",
    "$env:LOCALAPPDATA\Mozilla Firefox"
)
foreach ($folder in $foldersToRemove) {
    if (Test-Path $folder) {
        Remove-Item -Path $folder -Recurse -Force
        Add-Content -Path $logPath -Value "Removed folder: $folder"
    }
}

$regToRemove = "HKCU:\Software\Mozilla"
if (Test-Path $regToRemove) {
    Remove-Item -Path $regToRemove -Recurse -Force
    Add-Content -Path $logPath -Value "Removed registry key: $regToRemove"
}

# 4. remove start menu shortcuts
$startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Firefox.lnk"
if (Test-Path $startMenuPath) {
    Remove-Item -Path $startMenuPath -Force
    Add-Content -Path $logPath -Value "Removed Firefox Start Menu shortcut."
}

Add-Content -Path $logPath -Value "User-level cleanup finished."
exit 0
