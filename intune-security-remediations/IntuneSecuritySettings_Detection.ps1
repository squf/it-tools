Set-ExecutionPolicy Bypass -Scope Process -Force

$logFile = "C:\tmp\IntuneSecuritySettings_Detection.txt"

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


$compliant = $true

# SMB Signing (Client)
try {
    $val = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanManWorkstation\Parameters" -Name "RequireSecuritySignature" -ErrorAction Stop
    if ($val.RequireSecuritySignature -ne 1) {
        Log-Message "Non-compliant: SMB Signing (Client) is not required."
        $compliant = $false
    } else {
        Log-Message "Compliant: SMB Signing (Client) is required."
    }
} catch {
    Log-Message "Error checking SMB Signing (Client): $_"
    $compliant = $false
}

# SMB Signing (Server)
try {
    $val = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" -Name "RequireSecuritySignature" -ErrorAction Stop
    if ($val.RequireSecuritySignature -ne 1) {
        Log-Message "Non-compliant: SMB Signing (Server) is not required."
        $compliant = $false
    } else {
        Log-Message "Compliant: SMB Signing (Server) is required."
    }
} catch {
    Log-Message "Error checking SMB Signing (Server): $_"
    $compliant = $false
}

# TLS/SSL Protocols
$protocols = @(
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"; Name = "DisabledByDefault"; Expected = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client"; Name = "DisabledByDefault"; Expected = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"; Name = "DisabledByDefault"; Expected = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client"; Name = "DisabledByDefault"; Expected = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"; Name = "Enabled"; Expected = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client"; Name = "Enabled"; Expected = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"; Name = "Enabled"; Expected = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client"; Name = "Enabled"; Expected = 0 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"; Name = "Enabled"; Expected = 1 },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"; Name = "Enabled"; Expected = 1 }
)

foreach ($protocol in $protocols) {
    try {
        $val = Get-ItemProperty -Path $protocol.Path -Name $protocol.Name -ErrorAction Stop
        if ($val.$($protocol.Name) -ne $protocol.Expected) {
            Log-Message "Non-compliant: $($protocol.Path) $($protocol.Name) is not set to $($protocol.Expected)."
            $compliant = $false
        } else {
            Log-Message "Compliant: $($protocol.Path) $($protocol.Name) is set to $($protocol.Expected)."
        }
    } catch {
        Log-Message "Non-compliant: $($protocol.Path) $($protocol.Name) is missing."
        $compliant = $false
    }
}

# ECC Curve Order
try {
    $val = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Cryptography\Configuration\Local\SSL\00010002" -Name "EccCurves" -ErrorAction Stop
    if ($val.EccCurves -ne "curve25519,nistP384,nistP256") {
        Log-Message "Non-compliant: ECC Curve Order is not set to 'curve25519,nistP384,nistP256'."
        $compliant = $false
    } else {
        Log-Message "Compliant: ECC Curve Order is set to 'curve25519,nistP384,nistP256'."
    }
} catch {
    Log-Message "Error checking ECC Curve Order: $_"
    $compliant = $false
}

# Cipher Suites
$cipherSuites = @(
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
)

foreach ($cipherSuite in $cipherSuites) {
    try {
        if (-not (Get-TlsCipherSuite | Where-Object { $_.Name -eq $cipherSuite })) {
            Log-Message "Non-compliant: Cipher Suite $cipherSuite is not enabled."
            $compliant = $false
        } else {
            Log-Message "Compliant: Cipher Suite $cipherSuite is enabled."
        }
    } catch {
        Log-Message "Error checking Cipher Suite ${cipherSuite}: $_"
        $compliant = $false
    }
}

# SWEET32 Vulnerability Check
try {
    if (Get-TlsCipherSuite -Name "TLS_RSA_WITH_3DES_EDE_CBC_SHA") {
        Log-Message "Non-compliant: SWEET32 cipher TLS_RSA_WITH_3DES_EDE_CBC_SHA is enabled."
        $compliant = $false
    } else {
        Log-Message "Compliant: SWEET32 cipher TLS_RSA_WITH_3DES_EDE_CBC_SHA is not present."
    }
} catch {
    Log-Message "Error checking SWEET32 cipher: $_"
    $compliant = $false
}

# Final output for Intune
if ($compliant) {
    Log-Message "Overall Compliance: Compliant"
    Write-Output "Compliant"
    exit 0
} else {
    Log-Message "Overall Compliance: Non-compliant"
    Write-Output "Non-compliant"
    exit 1
}
