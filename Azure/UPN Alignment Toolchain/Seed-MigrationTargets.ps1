# ======================================================================================
# Seed-MigrationTargets.ps1
# UPN Alignment Project — One-Time Table Storage Seeder
#
# Runs on the Hybrid Worker. Queries on-prem AD using a filter template
# then writes every in-scope user to the MigrationTargets table in Azure Table Storage.
#
# Idempotent, can re-run whenever you need to pull new users into the storage table without breakage
#
# Author:  squf — Systems Administrator, IT Dept
# Project: Github — https://github.com/squf/it-tools/tree/main/Azure/UPN%20Alignment%20Toolchain
# ======================================================================================

param(
    [bool]$DryRun = $true,
    [string]$StorageAccountName = "[replace with your Storage Account name]",
    [string]$TableName = "MigrationTargets"
)

$ErrorActionPreference = "Stop"
$version = "1.0.0"
$timestamp = (Get-Date).ToUniversalTime().ToString("o")

Write-Output "========================================================================"
Write-Output "  Seed-MigrationTargets.ps1 v$version"
Write-Output "========================================================================"
Write-Output "  DryRun         : $DryRun"
Write-Output "  Storage Account: $StorageAccountName"
Write-Output "  Table          : $TableName"
Write-Output "  Started        : $timestamp"
Write-Output "========================================================================"

# --- Get Storage Key from Automation Variable ---
try {
    $storageKey = Get-AutomationVariable -Name "StorageAccountKey"
    Write-Output "[INIT] Retrieved StorageAccountKey from Automation Variables."
} catch {
    Write-Output "[FATAL] Could not retrieve StorageAccountKey: $($_.Exception.Message)"
    throw
}

# ======================================================================================
# Table Storage REST Helper — SharedKey Auth
# ======================================================================================
function Invoke-TableStorageRest {
    param(
        [string]$Method,
        [string]$AccountName,
        [string]$AccountKey,
        [string]$Resource,
        [string]$Body = ""
    )
    $uri = "https://$AccountName.table.core.windows.net/$Resource"
    $dateHeader = (Get-Date).ToUniversalTime().ToString("R")
    $contentType = if ($Body) { "application/json" } else { "" }

    # Canonicalized resource: /accountname/resource (strip query params for signing)
    $canonResource = "/$AccountName/$($Resource -replace '\?.*$','')"

    # StringToSign for Table Storage SharedKey:
    # VERB\nContent-MD5\nContent-Type\nDate\nCanonicalizedResource
    $stringToSign = "$Method`n`n$contentType`n$dateHeader`n$canonResource"

    $keyBytes = [Convert]::FromBase64String($AccountKey)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $keyBytes
    $sigBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signature = [Convert]::ToBase64String($sigBytes)

    $headers = @{
        "Authorization"  = "SharedKey ${AccountName}:${signature}"
        "x-ms-date"      = $dateHeader
        "x-ms-version"   = "2020-12-06"
        "Accept"         = "application/json;odata=nometadata"
        "Content-Type"   = "application/json"
    }

    $params = @{
        Uri     = $uri
        Method  = $Method
        Headers = $headers
    }
    if ($Body) { $params.Body = [Text.Encoding]::UTF8.GetBytes($Body) }

    Invoke-RestMethod @params
}

# ======================================================================================
# Template 1 — AD Query + Six-Stage Filter Pipeline
# ======================================================================================
Write-Output ""
Write-Output "[QUERY] Searching AD with Template filters..."

$searchBase = "[replace with your AD search base, e.g. OU=Users,DC=domain,DC=com]"
$excludeOUs = @("[replace with OU1]", "[replace with OU2]", "[replace with OU3]")
$excludeSAMs = @("[replace with SAM pattern 1, e.g. 'svc-*']", "[replace with SAM pattern 2, e.g. '*-admin']")
$excludeRecipientTypes = @([replace with recipient type code 1, e.g. 2147483648], [replace with recipient type code 2, e.g. 1073741824])

$adProperties = @(
    "UserPrincipalName","DisplayName","SamAccountName","proxyAddresses",
    "msExchRecipientTypeDetails","Enabled",
    "DistinguishedName"
)

$allUsers = Get-ADUser -SearchBase $searchBase -Filter * -Properties $adProperties

Write-Output "[QUERY] Raw AD objects found: $($allUsers.Count)"

$inScope = @()
$alignedCount = 0
$pendingCount = 0
$skippedCount = 0
$errorCount = 0
$results = @()

foreach ($user in $allUsers) {
    $sam = $user.SamAccountName
    $dn  = $user.DistinguishedName

    # --- Stage 1: OU Exclusion ---
    $excluded = $false
    foreach ($ou in $excludeOUs) {
        if ($dn -like "*$ou*") { $excluded = $true; break }
    }
    if ($excluded) { continue }

    # --- Stage 2: SAM Pattern Exclusion ---
    $samExcluded = $false
    foreach ($pattern in $excludeSAMs) {
        if ($sam -like $pattern) { $samExcluded = $true; break }
    }
    if ($samExcluded) { continue }

    # --- Stage 3: Recipient Type Exclusion ---
    $recipientType = $user.msExchRecipientTypeDetails
    if ($recipientType -and $excludeRecipientTypes -contains $recipientType) { continue }

    # --- Stage 4: Must be enabled ---
    if (-not $user.Enabled) { continue }

    # --- Stage 5: Must have primary SMTP ---
    $primarySMTP = ($user.proxyAddresses | Where-Object { $_ -cmatch '^SMTP:' }) -replace '^SMTP:',''
    if (-not $primarySMTP) { continue }

    # Passed all filters
    $currentUPN = $user.UserPrincipalName
    $targetUPN  = $primarySMTP

    if ($currentUPN -eq $targetUPN) {
        $status = "aligned"
        $alignedCount++
    } else {
        $status = "pending"
        $pendingCount++
    }

    $results += [PSCustomObject]@{
        SAM         = $sam
        DisplayName = $user.DisplayName
        CurrentUPN  = $currentUPN
        TargetUPN   = $targetUPN
        PrimarySMTP = $primarySMTP
        Status      = $status
    }
}

$totalFound = $results.Count
Write-Output "[QUERY] In-scope users after template filters: $totalFound"
Write-Output "        Aligned (UPN = SMTP): $alignedCount"
Write-Output "        Pending (UPN != SMTP): $pendingCount"

# ======================================================================================
# Write to Table Storage
# ======================================================================================
if ($DryRun) {
    Write-Output ""
    Write-Output "[DRYRUN] Would seed $totalFound entities to $TableName."
    Write-Output "[DRYRUN] Breakdown: $pendingCount pending + $alignedCount aligned"
    Write-Output ""
    Write-Output "[DRYRUN] Sample (first 10):"
    $results | Select-Object -First 10 | ForEach-Object {
        Write-Output "  $($_.SAM) | $($_.CurrentUPN) -> $($_.TargetUPN) | $($_.Status)"
    }
} else {
    Write-Output ""
    Write-Output "[SEED] Writing $totalFound entities to $TableName..."

    $successCount = 0

    foreach ($user in $results) {
        try {
            $entity = @{
                PartitionKey = "user"
                RowKey       = $user.SAM
                DisplayName  = $user.DisplayName
                CurrentUPN   = $user.CurrentUPN
                TargetUPN    = $user.TargetUPN
                PrimarySMTP  = $user.PrimarySMTP
                Status       = $user.Status
                LastUpdated  = $timestamp
                BatchId      = ""
                SkipReason   = ""
            } | ConvertTo-Json -Compress

            $resource = "$TableName(PartitionKey='user',RowKey='$($user.SAM)')"
            Invoke-TableStorageRest -Method "PUT" -AccountName $StorageAccountName `
                -AccountKey $storageKey -Resource $resource -Body $entity

            $successCount++

            if ($successCount % 50 -eq 0) {
                Write-Output "  ... $successCount / $totalFound written"
            }
        } catch {
            $errorCount++
            Write-Output "  [ERROR] $($user.SAM): $($_.Exception.Message)"
        }
    }

    Write-Output "[SEED] Complete: $successCount written, $errorCount errors."
}

# ======================================================================================
# Summary
# ======================================================================================
Write-Output ""
Write-Output "========================================================================"
Write-Output "  SEED SUMMARY"
Write-Output "========================================================================"
Write-Output "  Total in-scope : $totalFound"
Write-Output "  Aligned (skip) : $alignedCount"
Write-Output "  Pending (seed) : $pendingCount"
Write-Output "  Errors         : $errorCount"
Write-Output "  DryRun         : $DryRun"
Write-Output "  Finished       : $((Get-Date).ToUniversalTime().ToString('o'))"
Write-Output "========================================================================"
Write-Output ""
Write-Output "[DONE] Seed-MigrationTargets.ps1 completed."
