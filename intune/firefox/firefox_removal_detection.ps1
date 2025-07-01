$firefoxPaths = @(
    "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
    "$env:ProgramFiles(x86)\Mozilla Firefox\firefox.exe",
    "$env:APPDATA\Mozilla",
    "$env:LOCALAPPDATA\Mozilla"
)

$registryPaths = @(
    "HKLM:\Software\Mozilla",
    "HKLM:\Software\WOW6432Node\Mozilla",
    "HKCU:\Software\Mozilla",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

$found = $false

# Check file paths
foreach ($path in $firefoxPaths) {
    if (Test-Path $path) {
        Write-Output "Found Firefox file path: $path"
        $found = $true
    }
}

# Check registry uninstall entries
foreach ($reg in $registryPaths) {
    Get-ChildItem -Path $reg -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $displayName = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName
            if ($displayName -like "*Firefox*" -or $displayName -like "*Mozilla Maintenance*") {
                Write-Output "Found uninstall registry key: $($_.PSPath)"
                $found = $true
            }
        } catch {}
    }
}

# Check for Mozilla Maintenance Service
if (Get-Service -Name "MozillaMaintenance" -ErrorAction SilentlyContinue) {
    Write-Output "Mozilla Maintenance Service is installed"
    $found = $true
}

if (Test-Path "$env:ProgramFiles\Mozilla Maintenance Service") {
    Write-Output "Mozilla Maintenance Service folder exists"
    $found = $true
}

if ($found) {
    exit 1
} else {
    exit 0
}
