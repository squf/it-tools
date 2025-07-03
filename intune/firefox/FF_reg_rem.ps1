# FF_reg_rem.ps1 - Remediation script
$ErrorActionPreference = 'Stop'
$helperLog = "C:\tmp\FirefoxHelper.log"
$registryLog = "C:\tmp\FirefoxRegistry.log"

# Exit if FirefoxHelper.log does not exist
if (!(Test-Path $helperLog)) {
    Write-Output "FirefoxHelper.log not found. Exiting."
    exit 0
}

# Ensure log directory exists
if (!(Test-Path "C:\tmp")) { New-Item -Path "C:\tmp" -ItemType Directory -Force }
Set-Content -Path $registryLog -Value "Firefox Registry Cleanup Log - $(Get-Date)"

# Registry paths to remove
$registryPaths = @(
    "HKLM:\SOFTWARE\Mozilla",
    "HKLM:\SOFTWARE\mozilla.org",
    "HKLM:\SOFTWARE\MozillaPlugins",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MozillaMaintenanceService",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Mozilla",
    "HKLM:\SOFTWARE\WOW6432Node\Mozilla",
    "HKLM:\SOFTWARE\WOW6432Node\MozillaPlugins"
)

$allDeleted = $true

foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        try {
            $keys = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue
            foreach ($key in $keys) {
                Add-Content -Path $registryLog -Value "Deleting subkey: $($key.Name)"
            }
            Add-Content -Path $registryLog -Value "Deleting root key: $path"
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        } catch {
            Add-Content -Path $registryLog -Value "Failed to delete: $path - $_"
            $allDeleted = $false
        }
    } else {
        Add-Content -Path $registryLog -Value "Key not found: $path"
    }
}

# Verify deletion
foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        Add-Content -Path $registryLog -Value "Verification failed: $path still exists"
        $allDeleted = $false
    } else {
        Add-Content -Path $registryLog -Value "Verified deleted: $path"
    }
}

if ($allDeleted) {
    Add-Content -Path $registryLog -Value "All registry keys successfully deleted."
    exit 0
} else {
    Add-Content -Path $registryLog -Value "Some registry keys could not be deleted."
    exit 1
}
