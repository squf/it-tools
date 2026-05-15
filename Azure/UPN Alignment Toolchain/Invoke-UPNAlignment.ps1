<#
.SYNOPSIS
    Invoke-UPNAlignment.ps1 — Azure Hybrid Runbook for UPN-to-PrimarySMTP Alignment

.DESCRIPTION
    This runbook processes UPN-to-PrimarySMTP alignment changes for targeted users
    in on-premises Active Directory. It is designed to run on an Azure Automation
    Account via a Hybrid Runbook Worker with line-of-sight to your domain controllers.

    The script re-validates every target user against a five-stage filter pipeline
    before making any changes, ensuring no user outside project scope is ever
    accidentally modified.

    Safety: $DryRun defaults to $true. The script will NEVER write changes unless
    explicitly invoked with -DryRun $false.

.PARAMETER BatchId
    A GUID string linking this execution to an orchestration layer (e.g., Logic App,
    Static Web App, or any external caller). If not provided, a new GUID is generated.

.PARAMETER TargetUsers
    A JSON-encoded string array of UPN values to process.
    Example: '["jsmith","jdoe","agarcia"]'

.PARAMETER DryRun
    If $true (DEFAULT), the script performs full validation and conflict checking but
    writes nothing to AD. Reports exactly what WOULD change per user in the output JSON.

.PARAMETER ForceRevalidate
    If $true (DEFAULT), re-runs the full scope filter chain against each target user
    before processing. Set to $false only if you have pre-validated the batch externally
    and want to skip the per-user re-scope check (not recommended).

.PARAMETER ADSyncServer
    The hostname or FQDN of the server running Azure AD Connect, used to trigger a
    Delta Sync after all changes are committed. Defaults to "ADSYNC".

.PARAMETER MigrationBreadcrumbAttribute
    The AD extensionAttribute used to stamp a rollback breadcrumb on each migrated user.
    Defaults to "extensionAttribute14". Set to $null or empty string to disable stamping.

.NOTES
    Runtime  : PowerShell 7.2+ (Azure Hybrid Runbook Worker)
    Module   : ActiveDirectory
    License  : MIT

    Change Log:
      2026-05-12  v1.0.0  Initial public release — DryRun + Live execution pipeline
#>

# ======================================================================================
# 0. PARAMETERS
# ======================================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$BatchId = [guid]::NewGuid().ToString(),

    [Parameter(Mandatory = $true)]
    [string]$TargetUsers,

    [Parameter(Mandatory = $false)]
    [bool]$DryRun = $true,

    [Parameter(Mandatory = $false)]
    [bool]$ForceRevalidate = $true,

    [Parameter(Mandatory = $false)]
    [string]$ADSyncServer = "ADSYNC",

    [Parameter(Mandatory = $false)]
    [string]$MigrationBreadcrumbAttribute = "extensionAttribute14"
)

# ======================================================================================
# 1. IMPORT REQUIRED MODULES
# ======================================================================================

Import-Module ActiveDirectory

# ======================================================================================
# 2. CONFIGURATION — Scope Filter Chain
# ======================================================================================
# These values define which users are IN SCOPE for UPN alignment.
# Customize these to match your environment before first use.
#
# SearchBase            : The root OU/container to search within.
# ExcludedOUFragments   : Any DN containing these fragments is excluded.
# ExcludedSamPatterns   : Wildcard patterns for service/admin/test accounts.
# ExcludedRecipientTypes: msExchRecipientTypeDetails values for non-user mailboxes.

$Config = @{
    SearchBase          = "DC=YOURDOMAIN,DC=local"  # <-- REPLACE with your AD root or target OU
    ExcludedOUFragments = @(
        "OU=Disabled Accounts,"
        "OU=Service Accounts,"
        "OU=_Admin"
        "OU=_Resource"
    )
    ExcludedSamPatterns = @(
        "svc_*", "service.*",                       # Service accounts
        "admin*", "domainadmin_*", "globaladmin_*"        # Admin / privileged accounts
        "test*", "training*",                    # Non-production accounts
        "scan*", "fax*"                          # Device-linked accounts
    )
    ExcludedRecipientTypes = @(
        8589934592,  # RoomMailbox
        16,          # EquipmentMailbox
        32,          # MailContact
        128          # MailUser (non-employee)
    )
}

# ======================================================================================
# 3. HELPER FUNCTIONS
# ======================================================================================

function Get-ISOTimestamp {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

function Get-PrimarySMTP {
    <#
    .SYNOPSIS
        Extracts the primary SMTP address from a proxyAddresses array.
        Primary = the entry prefixed with uppercase "SMTP:" (not lowercase "smtp:").
    #>
    param([string[]]$ProxyAddresses)

    $primary = $ProxyAddresses | Where-Object { $_ -cmatch '^SMTP:' } | Select-Object -First 1
    if ($primary) {
        return $primary -replace '^SMTP:', ''
    }
    return $null
}

function Test-ScopeFilter {
    <#
    .SYNOPSIS
        Re-validates a single AD user object against the five-stage scope filter
        pipeline. Returns a hashtable: @{ InScope = $bool; SkipReason = $string }.
    #>
    param(
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        [hashtable]$FilterConfig
    )

    # --- Stage 1: OU Exclusion ---
    foreach ($frag in $FilterConfig.ExcludedOUFragments) {
        if ($User.distinguishedName -like "*$frag*") {
            return @{ InScope = $false; SkipReason = "OU exclusion: DN contains '$frag'" }
        }
    }

    # --- Stage 2: Naming Convention Exclusion ---
    foreach ($pat in $FilterConfig.ExcludedSamPatterns) {
        if ($User.SamAccountName -like $pat) {
            return @{ InScope = $false; SkipReason = "Naming convention exclusion: SAM '$($User.SamAccountName)' matches pattern '$pat'" }
        }
    }

    # --- Stage 3: Resource Mailbox Exclusion ---
    if ($User.msExchRecipientTypeDetails -in $FilterConfig.ExcludedRecipientTypes) {
        return @{ InScope = $false; SkipReason = "Recipient type exclusion: msExchRecipientTypeDetails = $($User.msExchRecipientTypeDetails)" }
    }

    # --- Stage 4: Primary SMTP Required ---
    $primarySmtp = Get-PrimarySMTP -ProxyAddresses $User.proxyAddresses
    if (-not $primarySmtp) {
        return @{ InScope = $false; SkipReason = "No primary SMTP address found in proxyAddresses" }
    }

    # --- Stage 5: Account Must Be Enabled ---
    if (-not $User.Enabled) {
        return @{ InScope = $false; SkipReason = "Account is disabled" }
    }

    return @{ InScope = $true; SkipReason = $null }
}

function Test-UPNConflict {
    <#
    .SYNOPSIS
        Checks whether the target UPN already exists on a DIFFERENT user object in AD.
        Also checks proxyAddresses for SMTP: collisions with other users.
        Returns a hashtable: @{ HasConflict = $bool; ConflictDetails = $string }.
    #>
    param(
        [string]$TargetUPN,
        [string]$SourceSam
    )

    # Check 1: Does another user already have this UPN?
    try {
        $existingUPN = Get-ADUser -Filter "userPrincipalName -eq '$TargetUPN'" -Properties SamAccountName -ErrorAction SilentlyContinue
        if ($existingUPN -and $existingUPN.SamAccountName -ne $SourceSam) {
            return @{
                HasConflict     = $true
                ConflictDetails = "UPN collision: '$TargetUPN' is already assigned to '$($existingUPN.SamAccountName)' ($($existingUPN.Name))"
            }
        }
    }
    catch {
        return @{
            HasConflict     = $true
            ConflictDetails = "Error checking UPN collision: $($_.Exception.Message)"
        }
    }

    # Check 2: Does another user have this as a primary SMTP proxy?
    try {
        $smtpCheck = "SMTP:$TargetUPN"
        $existingProxy = Get-ADUser -Filter "proxyAddresses -eq '$smtpCheck'" -Properties SamAccountName -ErrorAction SilentlyContinue
        if ($existingProxy -and $existingProxy.SamAccountName -ne $SourceSam) {
            return @{
                HasConflict     = $true
                ConflictDetails = "Proxy collision: 'SMTP:$TargetUPN' exists on '$($existingProxy.SamAccountName)' ($($existingProxy.Name))"
            }
        }
    }
    catch {
        # Non-fatal — proxy check is advisory
        Write-Warning "Could not complete proxy collision check for '$TargetUPN': $($_.Exception.Message)"
    }

    return @{ HasConflict = $false; ConflictDetails = $null }
}

# ======================================================================================
# 4. MAIN EXECUTION
# ======================================================================================

$batchStartTime = Get-ISOTimestamp
$results = [System.Collections.Generic.List[object]]::new()

$useBreadcrumb = -not [string]::IsNullOrWhiteSpace($MigrationBreadcrumbAttribute)

Write-Output "========================================================================"
Write-Output "   UPN Alignment Runbook — Invoke-UPNAlignment.ps1 v1.0.0"
Write-Output "========================================================================"
Write-Output "  Batch ID       : $BatchId"
Write-Output "  DryRun         : $DryRun"
Write-Output "  ForceRevalidate: $ForceRevalidate"
Write-Output "  ADSync Server  : $ADSyncServer"
Write-Output "  Breadcrumb Attr: $(if ($useBreadcrumb) { $MigrationBreadcrumbAttribute } else { '(disabled)' })"
Write-Output "  Started        : $batchStartTime"
Write-Output "========================================================================`n"

# --- Parse the TargetUsers JSON ---
try {
    # Azure Automation's test pane often strips JSON array syntax from string params.
    # Handle both formats: '["user1","user2"]' (proper JSON) and 'user1,user2' (bare CSV)
    $trimmed = $TargetUsers.Trim()

    if ($trimmed.StartsWith('[')) {
        $targetSams = @($trimmed | ConvertFrom-Json)
    }
    else {
        $targetSams = @($trimmed -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    }

    if ($targetSams.Count -eq 0) { throw "Parsed result is empty" }
    Write-Output "[INIT] Parsed $($targetSams.Count) target user(s) from TargetUsers input."
}
catch {
    $errorMsg = "FATAL: Failed to parse TargetUsers JSON. Error: $($_.Exception.Message)"
    Write-Error $errorMsg

    $failResult = @{
        batchId       = $BatchId
        batchStart    = $batchStartTime
        batchEnd      = (Get-ISOTimestamp)
        dryRun        = $DryRun
        totalTargeted = 0
        success       = 0
        skipped       = 0
        failed        = 1
        dryRunCount   = 0
        error         = $errorMsg
        users         = @()
    } | ConvertTo-Json -Depth 5

    Write-Output "###BATCH_RESULT_JSON###"
    Write-Output $failResult
    Write-Output "###END_BATCH_RESULT_JSON###"
    exit
}

# --- Validate: empty array ---
if ($targetSams.Count -eq 0) {
    Write-Warning "[INIT] TargetUsers array is empty. Nothing to process."

    $emptyResult = @{
        batchId       = $BatchId
        batchStart    = $batchStartTime
        batchEnd      = (Get-ISOTimestamp)
        dryRun        = $DryRun
        totalTargeted = 0
        success       = 0
        skipped       = 0
        failed        = 0
        dryRunCount   = 0
        error         = $null
        users         = @()
    } | ConvertTo-Json -Depth 5

    Write-Output "###BATCH_RESULT_JSON###"
    Write-Output $emptyResult
    Write-Output "###END_BATCH_RESULT_JSON###"
    exit
}

# --- AD Properties we need for every user ---
$adProperties = @(
    "userPrincipalName"
    "proxyAddresses"
    "mail"
    "msExchRecipientTypeDetails"
    "SamAccountName"
    "distinguishedName"
    "Enabled"
    "DisplayName"
)

# Include the breadcrumb attribute in the fetch list if configured
if ($useBreadcrumb) {
    $adProperties += $MigrationBreadcrumbAttribute
}

# ======================================================================================
# 5. PER-USER PROCESSING LOOP
# ======================================================================================

$changesMade = $false

foreach ($sam in $targetSams) {
    $userTimestamp = Get-ISOTimestamp
    Write-Output "------------------------------------------------------------------------"
    Write-Output "[USER] Processing: $sam"

    $userResult = @{
        sam         = $sam
        displayName = $null
        oldUPN      = $null
        newUPN      = $null
        primarySMTP = $null
        status      = $null
        skipReason  = $null
        errors      = [System.Collections.Generic.List[string]]::new()
        stateSnapshot = $null
        timestamp   = $userTimestamp
    }

    # ==================================================================================
    # Step 1: Fetch user from AD
    # ==================================================================================
    try {
        $adUser = Get-ADUser -Identity $sam -Properties $adProperties -ErrorAction Stop
        Write-Output "  [FETCH] Found: $($adUser.DisplayName) ($($adUser.userPrincipalName))"
    }
    catch {
        Write-Warning "  [FETCH] User '$sam' not found in AD or error retrieving: $($_.Exception.Message)"
        $userResult.status = "failed"
        $userResult.errors.Add("AD lookup failed: $($_.Exception.Message)")
        $results.Add([PSCustomObject]$userResult)
        continue
    }

    $userResult.displayName = $adUser.DisplayName
    $userResult.oldUPN = $adUser.userPrincipalName

    # ==================================================================================
    # Step 2: State Snapshot (pre-change record for audit / rollback)
    # ==================================================================================
    $userResult.stateSnapshot = @{
        userPrincipalName          = $adUser.userPrincipalName
        proxyAddresses             = @($adUser.proxyAddresses)
        mail                       = $adUser.mail
        msExchRecipientTypeDetails = $adUser.msExchRecipientTypeDetails
        sAMAccountName             = $adUser.SamAccountName
        distinguishedName          = $adUser.distinguishedName
        enabled                    = $adUser.Enabled
    }

    if ($useBreadcrumb) {
        $userResult.stateSnapshot[$MigrationBreadcrumbAttribute] = $adUser.$MigrationBreadcrumbAttribute
    }

    Write-Output "  [SNAPSHOT] State captured."

    # ==================================================================================
    # Step 3: Re-Scope Validation (filter chain)
    # ==================================================================================
    if ($ForceRevalidate) {
        $scopeCheck = Test-ScopeFilter -User $adUser -FilterConfig $Config
        if (-not $scopeCheck.InScope) {
            Write-Warning "  [SCOPE] SKIPPED — $($scopeCheck.SkipReason)"
            $userResult.status = "skipped"
            $userResult.skipReason = $scopeCheck.SkipReason
            $results.Add([PSCustomObject]$userResult)
            continue
        }
        Write-Output "  [SCOPE] Passed all scope filters."
    }
    else {
        Write-Output "  [SCOPE] ForceRevalidate=`$false — skipping re-scope check (pre-validated)."
    }

    # ==================================================================================
    # Step 4: Determine Target UPN (= Primary SMTP)
    # ==================================================================================
    $primarySmtp = Get-PrimarySMTP -ProxyAddresses $adUser.proxyAddresses
    $userResult.primarySMTP = $primarySmtp
    $userResult.newUPN = $primarySmtp

    # Check: Is UPN already aligned?
    if ($adUser.userPrincipalName -eq $primarySmtp) {
        Write-Output "  [MATCH] UPN already matches Primary SMTP. No change needed."
        $userResult.status = "skipped"
        $userResult.skipReason = "UPN already aligned with Primary SMTP"
        $results.Add([PSCustomObject]$userResult)
        continue
    }

    Write-Output "  [MISMATCH] Current UPN : $($adUser.userPrincipalName)"
    Write-Output "  [MISMATCH] Target UPN  : $primarySmtp"

    # ==================================================================================
    # Step 5: Conflict Check
    # ==================================================================================
    $conflictCheck = Test-UPNConflict -TargetUPN $primarySmtp -SourceSam $sam
    if ($conflictCheck.HasConflict) {
        Write-Warning "  [CONFLICT] $($conflictCheck.ConflictDetails)"
        $userResult.status = "failed"
        $userResult.errors.Add($conflictCheck.ConflictDetails)
        $results.Add([PSCustomObject]$userResult)
        continue
    }
    Write-Output "  [CONFLICT] No conflicts detected for target UPN."

    # ==================================================================================
    # Step 6: Execute or Report (DryRun gate)
    # ==================================================================================
    if ($DryRun) {
        Write-Output "  [DRYRUN] Would set UPN: $($adUser.userPrincipalName) -> $primarySmtp"
        Write-Output "  [DRYRUN] Would add proxy alias: smtp:$($adUser.userPrincipalName)"
        if ($useBreadcrumb) {
            Write-Output "  [DRYRUN] Would stamp $MigrationBreadcrumbAttribute: UPN-migrated-$userTimestamp"
        }
        $userResult.status = "dryrun"
        $results.Add([PSCustomObject]$userResult)
        continue
    }

    # --- LIVE EXECUTION ---
    Write-Output "  [LIVE] Applying changes..."
    $writeErrors = [System.Collections.Generic.List[string]]::new()

    # 6a. Set the new UPN
    try {
        Set-ADUser -Identity $sam -UserPrincipalName $primarySmtp -ErrorAction Stop
        Write-Output "  [LIVE] UPN updated: $($adUser.userPrincipalName) -> $primarySmtp"
    }
    catch {
        $errMsg = "Failed to set UPN: $($_.Exception.Message)"
        Write-Warning "  [LIVE] $errMsg"
        $writeErrors.Add($errMsg)
    }

    # 6b. Add old UPN as secondary proxy alias (lowercase smtp: = alias)
    try {
        $oldProxy = "smtp:$($adUser.userPrincipalName)"
        if ($adUser.proxyAddresses -notcontains $oldProxy) {
            Set-ADUser -Identity $sam -Add @{ proxyAddresses = $oldProxy } -ErrorAction Stop
            Write-Output "  [LIVE] Added proxy alias: $oldProxy"
        }
        else {
            Write-Output "  [LIVE] Proxy alias already exists: $oldProxy (skipped)"
        }
    }
    catch {
        $errMsg = "Failed to add proxy alias: $($_.Exception.Message)"
        Write-Warning "  [LIVE] $errMsg"
        $writeErrors.Add($errMsg)
    }

    # 6c. Stamp breadcrumb attribute for rollback traceability (optional)
    if ($useBreadcrumb) {
        try {
            $breadcrumb = "UPN-migrated-$userTimestamp"
            Set-ADUser -Identity $sam -Replace @{ $MigrationBreadcrumbAttribute = $breadcrumb } -ErrorAction Stop
            Write-Output "  [LIVE] Stamped ${MigrationBreadcrumbAttribute}: $breadcrumb"
        }
        catch {
            $errMsg = "Failed to stamp ${MigrationBreadcrumbAttribute}: $($_.Exception.Message)"
            Write-Warning "  [LIVE] $errMsg"
            $writeErrors.Add($errMsg)
        }
    }

    # ==================================================================================
    # Step 7: Post-Write Validation
    # ==================================================================================
    try {
        $postProperties = @("userPrincipalName", "proxyAddresses")
        if ($useBreadcrumb) { $postProperties += $MigrationBreadcrumbAttribute }

        $postUser = Get-ADUser -Identity $sam -Properties $postProperties -ErrorAction Stop

        $upnConfirmed   = $postUser.userPrincipalName -eq $primarySmtp
        $proxyConfirmed = $postUser.proxyAddresses -contains "smtp:$($adUser.userPrincipalName)"

        if ($upnConfirmed) {
            Write-Output "  [VALIDATE] UPN change confirmed."
        }
        else {
            $errMsg = "Post-write validation FAILED: UPN is '$($postUser.userPrincipalName)', expected '$primarySmtp'"
            Write-Warning "  [VALIDATE] $errMsg"
            $writeErrors.Add($errMsg)
        }

        if ($proxyConfirmed) {
            Write-Output "  [VALIDATE] Proxy alias confirmed."
        }
        else {
            $errMsg = "Post-write validation FAILED: Proxy alias 'smtp:$($adUser.userPrincipalName)' not found in proxyAddresses"
            Write-Warning "  [VALIDATE] $errMsg"
            $writeErrors.Add($errMsg)
        }

        if ($useBreadcrumb) {
            $attribConfirmed = $null -ne $postUser.$MigrationBreadcrumbAttribute -and $postUser.$MigrationBreadcrumbAttribute -like "UPN-migrated-*"
            if ($attribConfirmed) {
                Write-Output "  [VALIDATE] $MigrationBreadcrumbAttribute breadcrumb confirmed."
            }
            else {
                $errMsg = "Post-write validation FAILED: $MigrationBreadcrumbAttribute is '$($postUser.$MigrationBreadcrumbAttribute)', expected 'UPN-migrated-*'"
                Write-Warning "  [VALIDATE] $errMsg"
                $writeErrors.Add($errMsg)
            }
        }
    }
    catch {
        $errMsg = "Post-write validation error: $($_.Exception.Message)"
        Write-Warning "  [VALIDATE] $errMsg"
        $writeErrors.Add($errMsg)
    }

    # --- Final status determination for this user ---
    if ($writeErrors.Count -gt 0) {
        $userResult.status = "failed"
        foreach ($e in $writeErrors) { $userResult.errors.Add($e) }
    }
    else {
        $userResult.status = "success"
        $changesMade = $true
    }

    $results.Add([PSCustomObject]$userResult)
}

# ======================================================================================
# 6. DELTA SYNC TRIGGER (once per batch, only if changes were made)
# ======================================================================================

$syncTriggered = $false
$syncError = $null

if (-not $DryRun -and $changesMade) {
    Write-Output "`n========================================================================"
    Write-Output "[SYNC] Triggering Delta Sync on $ADSyncServer..."
    Write-Output "========================================================================`n"

    try {
        Invoke-Command -ComputerName $ADSyncServer -ScriptBlock {
            Import-Module ADSync
            Start-ADSyncSyncCycle -PolicyType Delta
        } -ErrorAction Stop

        $syncTriggered = $true
        Write-Output "[SYNC] Delta Sync triggered successfully."
    }
    catch {
        $syncError = "Failed to trigger Delta Sync on '$ADSyncServer': $($_.Exception.Message)"
        Write-Warning "[SYNC] $syncError"
        Write-Warning "[SYNC] You may need to manually trigger a Delta Sync: Start-ADSyncSyncCycle -PolicyType Delta"
    }
}
elseif ($DryRun) {
    Write-Output "`n[SYNC] DryRun mode — Delta Sync not triggered."
}
else {
    Write-Output "`n[SYNC] No changes were committed — Delta Sync not triggered."
}

# ======================================================================================
# 7. BATCH SUMMARY & JSON OUTPUT
# ======================================================================================

$batchEndTime = Get-ISOTimestamp

$successCount = ($results | Where-Object { $_.status -eq "success" }).Count
$skippedCount = ($results | Where-Object { $_.status -eq "skipped" }).Count
$failedCount  = ($results | Where-Object { $_.status -eq "failed"  }).Count
$dryRunCount  = ($results | Where-Object { $_.status -eq "dryrun"  }).Count

Write-Output "`n========================================================================"
Write-Output "  BATCH SUMMARY"
Write-Output "========================================================================"
Write-Output "  Batch ID      : $BatchId"
Write-Output "  DryRun        : $DryRun"
Write-Output "  Total targeted: $($targetSams.Count)"
Write-Output "  Success       : $successCount"
Write-Output "  Skipped       : $skippedCount"
Write-Output "  Failed        : $failedCount"
Write-Output "  DryRun preview: $dryRunCount"
Write-Output "  Delta Sync    : $(if ($syncTriggered) { 'Triggered' } elseif ($syncError) { 'FAILED' } else { 'Not triggered' })"
Write-Output "  Started       : $batchStartTime"
Write-Output "  Finished      : $batchEndTime"
Write-Output "========================================================================`n"

# --- Build the final JSON payload for downstream consumers ---
$batchResult = @{
    batchId       = $BatchId
    batchStart    = $batchStartTime
    batchEnd      = $batchEndTime
    dryRun        = $DryRun
    totalTargeted = $targetSams.Count
    success       = $successCount
    skipped       = $skippedCount
    failed        = $failedCount
    dryRunCount   = $dryRunCount
    deltaSync     = @{
        triggered = $syncTriggered
        error     = $syncError
        server    = $ADSyncServer
    }
    error         = $null
    users         = @($results | ForEach-Object {
        @{
            sam         = $_.sam
            displayName = $_.displayName
            oldUPN      = $_.oldUPN
            newUPN      = $_.newUPN
            primarySMTP = $_.primarySMTP
            status      = $_.status
            skipReason  = $_.skipReason
            errors      = @($_.errors)
            timestamp   = $_.timestamp
        }
    })
}

# Serialize to JSON — delimiters allow downstream consumers (Logic App, webhook, etc.)
# to reliably parse the structured output from the runbook's stdout stream
$jsonOutput = $batchResult | ConvertTo-Json -Depth 10 -Compress

Write-Output "###BATCH_RESULT_JSON###"
Write-Output $jsonOutput
Write-Output "###END_BATCH_RESULT_JSON###"

Write-Output "`n[DONE] Invoke-UPNAlignment.ps1 completed."
