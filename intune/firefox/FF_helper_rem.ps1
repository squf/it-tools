# FF_helper.ps1 - Firefox silent uninstaller
$ErrorActionPreference = 'SilentlyContinue'
$logPath = "C:\tmp\FirefoxHelper.log"

# Create log directory if it doesn't exist
if (!(Test-Path "C:\tmp")) { New-Item -Path "C:\tmp" -ItemType Directory -Force }
Set-Content -Path $logPath -Value "Firefox Silent Uninstall Log - $(Get-Date)"

# Define paths to helper.exe
$exePaths = @(
    "C:\Program Files\Mozilla Firefox\uninstall\helper.exe",
    "C:\Program Files (x86)\Mozilla Firefox\uninstall\helper.exe"
)

# Stop any running Firefox processes
Add-Content -Path $logPath -Value "Stopping Firefox processes..."
Get-Process -Name "firefox" -ErrorAction SilentlyContinue | Stop-Process -Force

# Run helper.exe if found
foreach ($exe in $exePaths) {
    if (Test-Path $exe) {
        Add-Content -Path $logPath -Value "Running uninstaller: $exe"
        $process = Start-Process -FilePath $exe -ArgumentList "/S" -Wait -NoNewWindow -PassThru
        $exitCode = $process.ExitCode
        Add-Content -Path $logPath -Value "Uninstaller exited with code: $exitCode"
    } else {
        Add-Content -Path $logPath -Value "Uninstaller not found at: $exe"
    }
}

# Verify uninstallation by checking if folders still exist
$foldersToCheck = @(
    "C:\Program Files\Mozilla Firefox",
    "C:\Program Files (x86)\Mozilla Firefox"
)

$remaining = @()
foreach ($folder in $foldersToCheck) {
    if (Test-Path $folder) {
        Add-Content -Path $logPath -Value "Folder still exists: $folder"
        $remaining += $folder
    } else {
        Add-Content -Path $logPath -Value "Folder removed: $folder"
    }
}

# Exit with code 0 if all folders are removed, 1 otherwise
if ($remaining.Count -eq 0) {
    Add-Content -Path $logPath -Value "Firefox uninstallation successful."
    exit 0
} else {
    Add-Content -Path $logPath -Value "Firefox uninstallation incomplete."
    exit 1
}
