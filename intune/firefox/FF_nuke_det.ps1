# FF_nuke_det.ps1 - Exits 1 if any Firefox artifact is found, 0 otherwise.
$ErrorActionPreference = 'SilentlyContinue'
$firefoxFound = $false
$registryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
$serviceName = 'MozillaMaintenance'
$installFolders = @(
    "$env:ProgramFiles\Mozilla Firefox",
    "$env:ProgramFiles(x86)\Mozilla Firefox"
)
foreach ($path in $registryPaths) {
    if (Get-ChildItem -Path $path | Get-ItemProperty | Where-Object { $_.DisplayName -like '*Mozilla Firefox*' }) {
        $firefoxFound = $true
        break
    }
}
if (!$firefoxFound) {
    if (Get-Service -Name $serviceName) {
        $firefoxFound = $true
    }
}
if (!$firefoxFound) {
    foreach ($folder in $installFolders) {
        if (Test-Path $folder) {
            $firefoxFound = $true
            break
        }
    }
}
if ($firefoxFound) {
    Write-Output "Firefox artifacts found. Remediation required."
    exit 1
} else {
    Write-Output "No Firefox artifacts found. System is clean."
    exit 0
}
