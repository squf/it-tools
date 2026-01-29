# ==============================================================================
# SQUF'S BASH-LIKE POWERSHELL PROFILE
# Target: PowerShell 7+ | Location: $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
# ==============================================================================

# --- 1. LINUX-STYLE ALIASES ---
# PowerShell has some of these built-in, but these ensure consistency
New-Alias -Name touch -Value New-Item -Force -ErrorAction SilentlyContinue
New-Alias -Name grep  -Value Select-String
Set-Alias  -Name ll    -Value ls        # Custom 'll' for list-long style (standard ls works anyway)
Set-Alias  -Name which -Value Get-Command

# --- 2. THE 'RUN' ENGINE (Transient Sessions) ---
function run {
    <#
    .SYNOPSIS
        Runs a PowerShell script in a clean, non-persistent session.
    .EXAMPLE
        run example.ps1
    #>
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Script
    )
    
    $Path = Resolve-Path $Script
    Write-Host "🚀 Launching Clean Session: $($Path.FileName)" -ForegroundColor Cyan
    
    # -NoProfile: No startup junk
    # -ExecutionPolicy Bypass: Run despite restrictive local policies
    pwsh -NoProfile -ExecutionPolicy Bypass -File $Path
}

# --- 3. CUSTOM PROMPT (Clean & Minimal) ---
function prompt {
    # ESC [ 38;5;### m  is the code for 256-color mode
    $cyan   = "$([char]27)[38;5;81m"   # A nice bright Cyan/Blue
    $purple = "$([char]27)[38;5;141m"  # A soft purple
    $gray   = "$([char]27)[38;5;244m"  # Dimmer gray for the brackets
    $reset  = "$([char]27)[0m"         # Resets color to default

    $currentDir = Split-Path -Leaf (Get-Location)
    
    # Building: [shell] > 
    Write-Host -NoNewline "$gray["
    Write-Host -NoNewline "$purple$currentDir"
    Write-Host -NoNewline "$gray]$cyan > $reset"
    return " "
}
# Syntax Highlighting for your typing
Set-PSReadLineOption -Colors @{
    Command            = "$([char]27)[38;5;81m"   # Commands you type will be Cyan
    Parameter          = "$([char]27)[38;5;244m"  # Parameters (-Name, -Scope) will be Gray
    String             = "$([char]27)[38;5;150m"  # Strings in quotes will be Greenish
    Variable           = "$([char]27)[38;5;209m"  # Variables ($var) will be Salmon/Orange
}

# --- 4. GRAPH SDK HELPER ---
# Ensuring we always point to the local local system path for modules
$env:PSModulePath = "C:\Program Files\PowerShell\Modules;" + $env:PSModulePath
