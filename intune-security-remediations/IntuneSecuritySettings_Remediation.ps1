$logFile = "C:\tmp\IntuneSecuritySettings_Remediation.txt"

# Ensure the log directory exists
if (-Not (Test-Path -Path "C:\tmp")) {
    New-Item -Path "C:\tmp" -ItemType Directory
}

# Clear the log file at the start of the script
if (Test-Path -Path $logFile) {
    Clear-Content -Path $logFile -ErrorAction SilentlyContinue
}

function Log-Message {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp - $message"
}

Log-Message "Starting Intune Security Settings Remediation Script"

# SMB Signing
$settings = @(
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\LanManWorkstation\Parameters"; Name = "RequireSecuritySignature"; Value = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters"; Name = "RequireSecuritySignature"; Value = 1 }
)

foreach ($setting in $settings) {
    try {
        Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type DWord
        Log-Message "Set $($setting.Name) to $($setting.Value) at $($setting.Path)"
    } catch {
        Log-Message "Error setting $($setting.Name): $_"
    }
}

# TLS/SSL Protocol settings
$protocols = @(
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"; Name = "Enabled"; Value = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client"; Name = "Enabled"; Value = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"; Name = "Enabled"; Value = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client"; Name = "Enabled"; Value = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"; Name = "Enabled"; Value = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client"; Name = "Enabled"; Value = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"; Name = "Enabled"; Value = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"; Name = "Enabled"; Value = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"; Name = "Enabled"; Value = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"; Name = "Enabled"; Value = 1 }
)

foreach ($protocol in $protocols) {
    try {
        if (-not (Test-Path $protocol.Path)) {
            New-Item -Path $protocol.Path -Force | Out-Null
            Log-Message "Created missing registry path: $($protocol.Path)"
        }
        New-ItemProperty -Path $protocol.Path -Name $protocol.Name -Value $protocol.Value -PropertyType DWord -Force | Out-Null
        Log-Message "Successfully set $($protocol.Name) to $($protocol.Value) at $($protocol.Path)"
    } catch {
        Log-Message "Error setting $($protocol.Name) at $($protocol.Path): $_"
    }
}

# TLS 1.2 Server and Client - Ensure Enabled and DisabledByDefault are explicitly set
$paths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server",
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"
)

foreach ($path in $paths) {
    try {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
            Log-Message "Created missing TLS 1.2 path: $path"
        }
        New-ItemProperty -Path $path -Name "Enabled" -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $path -Name "DisabledByDefault" -Value 0 -PropertyType DWord -Force | Out-Null
        Log-Message "Set TLS 1.2 settings at $path (Enabled=1, DisabledByDefault=0)"
    } catch {
        Log-Message "Error configuring TLS 1.2 at ${path}: $_"
    }
}

# ECC Curve Order
$eccCurves = @("curve25519", "nistP384", "nistP256")
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Cryptography\Configuration\Local\SSL\00010002" -Name "EccCurves" -Value $eccCurves -Type MultiString
    Log-Message "Successfully set ECC Curves to $($eccCurves -join ', ')"
} catch {
    Log-Message "Error setting ECC Curves: $_"
}

# Define only the approved cipher suites
$cipherSuites = @(
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
)

# Overwrite the registry with only the approved cipher suites
try {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Cryptography\Configuration\Local\SSL\00010002"
    Set-ItemProperty -Path $regPath -Name Functions -Value $cipherSuites -Type MultiString
    Log-Message "Successfully set approved cipher suites only."
} catch {
    Log-Message "Error setting cipher suites: $_"
}

# SWEET32 Remediation - Remove TLS_RSA_WITH_3DES_EDE_CBC_SHA
try {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Cryptography\Configuration\Local\SSL\00010002"
    $current = (Get-ItemProperty -Path $regPath -Name Functions -ErrorAction Stop).Functions
    $updated = $current | Where-Object { $_ -ne "TLS_RSA_WITH_3DES_EDE_CBC_SHA" }

    if ($updated.Count -ne $current.Count) {
        Set-ItemProperty -Path $regPath -Name Functions -Value $updated -Type MultiString
        Log-Message "Removed SWEET32 cipher TLS_RSA_WITH_3DES_EDE_CBC_SHA from registry."
    } else {
        Log-Message "SWEET32 cipher TLS_RSA_WITH_3DES_EDE_CBC_SHA not found in registry list."
    }
} catch {
    Log-Message "Error removing SWEET32 cipher from registry: $_"
}

Log-Message "Completed Intune Security Settings Remediation Script"
