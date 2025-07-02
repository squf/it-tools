# detection script - run in user context
$ErrorActionPreference = 'SilentlyContinue'
$found = $false

# check user registry for uninstall key
$uninstallKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$firefoxApp = Get-ChildItem -Path $uninstallKey | Get-ItemProperty | Where-Object { $_.DisplayName -like 'Mozilla Firefox*' }
if ($firefoxApp) {
    Write-Output "Found Firefox uninstall key in HKCU."
    $found = $true
}

# check for user profile folders
$userFolders = @(
    "$env:APPDATA\Mozilla",
    "$env:LOCALAPPDATA\Mozilla",
    "$env:LOCALAPPDATA\Mozilla Firefox"
)
foreach ($folder in $userFolders) {
    if (Test-Path $folder) {
        Write-Output "Found Firefox folder at: $folder"
        $found = $true
        break # exit loop once one is found
    }
}

# check for start menu shortcuts
$startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Firefox.lnk"
if (Test-Path $startMenuPath) {
    Write-Output "Found Firefox Start Menu shortcut."
    $found = $true
}

if ($found) {
    exit 1 # found, remediation needed
} else {
    exit 0 # not found, all good
}
