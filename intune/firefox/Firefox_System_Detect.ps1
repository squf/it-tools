# detection script - run as system
$ErrorActionPreference = 'SilentlyContinue'
$found = $false

# check for mozilla maintenance service
$service = Get-Service -Name "MozillaMaintenance" -ErrorAction SilentlyContinue
if ($service) {
    Write-Output "Found Mozilla Maintenance Service."
    $found = $true
}

# check system registry for uninstall key
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($path in $uninstallPaths) {
    $firefoxApp = Get-ChildItem -Path $path | Get-ItemProperty | Where-Object { $_.DisplayName -like 'Mozilla Firefox*' -or $_.DisplayName -like 'Mozilla Maintenance Service' }
    if ($firefoxApp) {
        Write-Output "Found Firefox or Maintenance Service uninstall key in HKLM."
        $found = $true
        break
    }
}

# check for system-level folders
$systemFolders = @(
    "$env:ProgramFiles\Mozilla Firefox",
    "$env:ProgramFiles(x86)\Mozilla Firefox",
    "$env:ProgramFiles\Mozilla Maintenance Service",
    "$env:ProgramFiles(x86)\Mozilla Maintenance Service"
)
foreach ($folder in $systemFolders) {
    if (Test-Path $folder) {
        Write-Output "Found system folder at: $folder"
        $found = $true
        break
    }
}

if ($found) {
    exit 1 # found, remediation needed
} else {
    exit 0 # not found, all good
}
