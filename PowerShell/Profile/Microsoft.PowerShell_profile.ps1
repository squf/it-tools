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
# --- 4. THE 'MAN' FUNCTION ---
function man {
    param([string]$Command)
    if ($Command) {
        # This reaches into the help object and pulls ONLY the example blocks
        (Get-Help $Command).examples | Out-String | Write-Host -ForegroundColor Yellow
    } else {
        Write-Host "Usage: man <cmdlet>" -ForegroundColor Gray
    }
}

# --- 5. THE 'HOW' COMMAND ---
function how {
    param([string]$topic)

    $cheats = @{
        "graph" = @(
            "Connect: Connect-MgGraph -Scopes 'User.Read.All'",
            "Find User: Get-MgUser -Filter `"displayName eq 'squf'`"",
            "Check Scopes: (Get-MgContext).Scopes"
        )
        "files" = @(
            "Find text: grep 'search' file.ps1",
            "List local: ll",
            "Make file: touch newfile.txt"
        )
        "entraid" = @(
            "List Groups: Get-MgGroup -All",
            "User Memberships: Get-MgUserMemberOf -UserId <ID>"
        )
        "upn" = @(
            "Check UPN: Get-MgUser -UserId <Email> | Select UserPrincipalName",
            "Update UPN: Update-MgUser -UserId <ID> -UserPrincipalName <NewUPN>"
        )
        "aliases" = @(
            "man: Get-Help <cmdlet> -Examples",
            "touch: New-Item -ItemType File <filename>",
            "grep: Select-String 'text' <file>",
            "which: Get-Command <cmdlet>",
            "ll: ls -l"
        )
    }

    if ($topic -and $cheats.ContainsKey($topic)) {
        Write-Host "`n--- Cheat Sheet for [$topic] ---" -ForegroundColor Cyan
        $cheats[$topic] | ForEach-Object { Write-Host "  > $_" -ForegroundColor Yellow }
        Write-Host ""
    } else {
        Write-Host "Usage: how <topic>. Available topics: $($cheats.Keys -join ', ')" -ForegroundColor Gray
    }
}

# --- 6. GRAPH SDK HELPER ---
# Ensuring we always point to the local local system path for modules
$env:PSModulePath = "C:\Program Files\PowerShell\Modules;" + $env:PSModulePath
