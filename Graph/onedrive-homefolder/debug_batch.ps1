# Begin Script --- Prompt for username and log directory, then upload files to OneDrive using Microsoft Graph API
# This is just a debugging script made separately to fix Graph API call issues with the primary ODHF.ps1, there's no need to use this script at all, I've just posted it here for historical / archiving purposes
# It is helpful to get an idea of how you could structure a script for debugging, basically just wrapping your entire script with logging and API responses into a log file
# DEBUG VERSION: Includes enhanced API request and response logging to a local file.
# Requires: get-token.ps1 to be run first to set $Auth.access_token

$username = Read-Host "Enter the username (e.g., FirstnameL)"

#==================================================================
# ✨ SETUP AND VALIDATION (DEBUG-ENABLED) ✨
#==================================================================

# === LOGGING SETUP ===
# The log file will be created in the same directory as the script.
if ($PSScriptRoot) {
    $logDir = $PSScriptRoot
} else {
    $logDir = $PWD.Path
    Write-Host "INFO: `$PSScriptRoot is not defined. Using current working directory for logs: $logDir" -ForegroundColor Yellow
}
$logFile = Join-Path $logDir "ODHF-debug-log-$($username)-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $message"
    # Write to both host and the log file
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

Write-Log "=========================================================="
Write-Log "🚀 Starting Script: debug_batch.ps1"
Write-Log "Logging to file: $logFile"
Write-Log "=========================================================="

# === DEFINE PATHS ===
$baseLocalRoot    = "\\<YOUR_DATA_SERVER_HERE>\<YOUR_HOME_FOLDER_DIR>" # Update this line with your onprem Home Folder server UNC path
$localPath        = Join-Path $baseLocalRoot $username
$userPrincipalName = "$($username)@company.com" # Update this line with your company value
$remoteFolder     = "Home Folder" # This is the root folder to be created in OneDrive
$LargeFileThreshold = 15 * 1024 * 1024 # 15 MB

# === VALIDATE AUTH TOKEN ===
if (-not $Auth.access_token) {
    Write-Log "❌ Auth token not found in `$Auth.access_token. Please run your authentication script first."
    exit
}
$headers = @{ Authorization = "Bearer $($Auth.access_token)" }

# === VALIDATE LOCAL FOLDER ===
if (-not (Test-Path -LiteralPath $localPath)) {
    Write-Log "❌ Local folder not found: $localPath. Please check the username and network path."
    exit
}

# === CONFIRMATION ===
Write-Log "`n🧾 Summary of Operation:"
Write-Log "--------------------------------------------------"
Write-Log "📁 Source (On-Prem): '$localPath'"
Write-Log "👤 Target User: '$userPrincipalName'"
Write-Log "☁️  OneDrive Destination: '$remoteFolder'"
Write-Log "--------------------------------------------------"
$confirm = Read-Host "`nProceed with migration? (Y/N)"
if ($confirm -ne 'Y') {
    Write-Log "❌ Operation cancelled by user."
    exit
}

#==================================================================
# ✨ API HELPER FUNCTIONS (WITH DETAILED LOGGING) ✨
#==================================================================

function Invoke-GraphApiRequestWithRetry {
    param(
        [Parameter(Mandatory = $true)] [hashtable]$Splat,
        [int]$MaxRetries = 5,
        [int]$DefaultRetryAfterSeconds = 30
    )

    # --- 📤 Start Enhanced API Request Logging ---
    Write-Log " " # Add a blank line for readability
    Write-Log "------------------- 📤 API Request Sent -------------------"
    Write-Log "METHOD: $($Splat.Method)"
    Write-Log "URI: $($Splat.Uri)"

    # Clone headers to redact the token for safe logging
    $headersToLog = $Splat.Headers.Clone()
    if ($headersToLog.Authorization) { $headersToLog.Authorization = "Bearer [REDACTED_FOR_LOG]" }
    Write-Log "HEADERS: $($headersToLog | ConvertTo-Json -Depth 2 -Compress)"

    if ($Splat.Body) {
        Write-Log "BODY (This is the exact payload sent to the API):"
        # The body might be a multi-line JSON string; log it as is for easy copying.
        Add-Content -Path $logFile -Value $Splat.Body
        # Also show a compressed version on console if it's JSON
        if ($Splat.Body -is [string] -and $Splat.Body.Trim().StartsWith('{')) {
           Write-Host "$($Splat.Body.Replace("`r`n", ' ').Replace("`n", ' '))"
        }
    }
    Write-Log "----------------------------------------------------------"
    # --- End Enhanced API Request Logging ---

    $retryCount = 0
    while ($true) {
        try {
            # Execute the API Call
            $response = Invoke-RestMethod @Splat

            # --- 📥 Start Successful API Response Logging ---
            Write-Log "------------------- 📥 API Response (Success) -------------------"
            if ($response) {
                $responseJson = $response | ConvertTo-Json -Depth 5
                Write-Log "RESPONSE BODY:"
                Add-Content -Path $logFile -Value $responseJson
            } else {
                Write-Log "RESPONSE BODY: (No content)"
            }
            Write-Log "-------------------------------------------------------------"
            # --- End Successful API Response Logging ---
            return $response
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $errorResponse = $_.Exception.Response
            
            # === THIS IS THE CORRECTED PART (v2) ===
            # The full error message, including the body, is contained in the exception's Message property.
            # This is a safer way to get the content and avoids the "disposed object" error.
            $errorContent = $_.Exception.Message
            
            # --- 📥 Start Error API Response Logging ---
            Write-Log "!!!!!!!!!!!!!!!!!!! 📥 API Response (Error) !!!!!!!!!!!!!!!!!!!"
            Write-Log "STATUS CODE: $($errorResponse.StatusCode.value__)"
            Write-Log "ERROR DETAILS:"
            # Log the full error message from the exception
            Add-Content -Path $logFile -Value $errorContent
            Write-Log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            # --- End Error API Response Logging ---

            if ($errorResponse.StatusCode.value__ -eq 429 -and $retryCount -lt $MaxRetries) {
                $retryCount++
                $retryAfterHeader = $_.Exception.Response.Headers['Retry-After']
                $waitTimeSeconds = $DefaultRetryAfterSeconds
                if ($null -ne $retryAfterHeader) {
                    if (-not ([int]::TryParse($retryAfterHeader, [ref]$waitTimeSeconds))) {
                        try {
                            $retryDate = [datetimeoffset]::Parse($retryAfterHeader, [System.Globalization.CultureInfo]::InvariantCulture)
                            $secondsToWait = ($retryDate - [datetimeoffset]::UtcNow).TotalSeconds
                            if ($secondsToWait -gt 0) { $waitTimeSeconds = [math]::Ceiling($secondsToWait) }
                        } catch { Write-Log "⚠️ Could not parse Retry-After date header. Using default." }
                    }
                }
                if ($waitTimeSeconds -gt 300) { $waitTimeSeconds = 300 } # Max wait 5 mins
                if ($waitTimeSeconds -le 0) { $waitTimeSeconds = 1 }
                Write-Log "⏳ API throttled (429). Retrying in $waitTimeSeconds seconds... (Attempt $retryCount of $MaxRetries)"
                Start-Sleep -Seconds $waitTimeSeconds
            }
            else { throw } # Re-throw the original error if not a 429 or retries exhausted
        }
        catch {
             # --- 💥 Start Generic Error Logging ---
            Write-Log "!!!!!!!!!!!!!!!!!!! 💥 UNHANDLED EXCEPTION 💥 !!!!!!!!!!!!!!!!!!!"
            Write-Log "An unexpected error occurred during the API call: $($_.Exception.Message)"
            Write-Log "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
             # --- End Generic Error Logging ---
            throw # Re-throw
        }
    }
}

function Invoke-GraphBatchRequest {
    param(
        [Parameter(Mandatory=$true)] [array]$Requests,
        [Parameter(Mandatory=$true)] [hashtable]$Headers
    )
    if ($Requests.Count -eq 0) { return }
    $batchUrl = "https://graph.microsoft.com/v1.0/`$batch"
    
    # This is the key part for batching. The entire payload, including the 'requests'
    # array, is converted to JSON in one go. The logger will now show this exact string.
    $batchPayload = @{ requests = $Requests }
    $batchJsonBody = $batchPayload | ConvertTo-Json -Depth 10

    $irmParams = @{
        Uri         = $batchUrl
        Headers     = $Headers
        Method      = 'POST'
        Body        = $batchJsonBody
        ContentType = "application/json"
    }
    # This function call will now be logged in detail
    return Invoke-GraphApiRequestWithRetry -Splat $irmParams
}

function Upload-LargeFile {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$FileItem,
        [Parameter(Mandatory = $true)][string]$FullRemotePath,
        [Parameter(Mandatory = $true)][string]$DriveId,
        [Parameter(Mandatory = $true)][hashtable]$Headers
    )
    $encodedFullRemoteFilePath = ($FullRemotePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $sessionUrl = "https://graph.microsoft.com/v1.0/drives/$DriveId/root:/$($encodedFullRemoteFilePath):/createUploadSession"
    $sessionBody = @{ item = @{ "@microsoft.graph.conflictBehavior" = "fail" } } | ConvertTo-Json
    try {
        Write-Log "Creating upload session for '$($FileItem.Name)'..."
        $irmParams = @{ Uri = $sessionUrl; Headers = $Headers; Method = 'POST'; Body = $sessionBody; ContentType = "application/json" }
        $sessionResponse = Invoke-GraphApiRequestWithRetry -Splat $irmParams
        $uploadUrl = $sessionResponse.uploadUrl
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 409) { Write-Log "⏭️ Skipping large file '$($FileItem.Name)' — already exists." }
        else { Write-Log "❌ Failed to create upload session for '$($FileItem.Name)': $($_.Exception.Message)" }
        return
    }
    $chunkSize = 5 * 1024 * 1024
    $fileStream = [System.IO.File]::OpenRead($FileItem.FullName)
    $buffer = New-Object byte[] $chunkSize
    $bytesUploaded = 0
    $totalBytes = $FileItem.Length
    $progress = -1
    try {
        while ($bytesUploaded -lt $totalBytes) {
            $bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -eq 0) { break }
            $startRange = $bytesUploaded
            $endRange = $bytesUploaded + $bytesRead - 1
            $uploadHeaders = @{ "Content-Range" = "bytes $startRange-$endRange/$totalBytes" }
            $chunkData = New-Object byte[] $bytesRead
            [System.Array]::Copy($buffer, 0, $chunkData, 0, $bytesRead)
            $newProgress = [math]::Round(($endRange + 1) / $totalBytes * 100)
            if ($newProgress -gt $progress) {
                $progress = $newProgress
                Write-Host "`rUploading '$($FileItem.Name)': $progress% " -NoNewline
            }
            # Note: Chunk uploads are not logged in full detail to avoid spamming the log with binary data.
            # We rely on the session creation and finalization logs.
            $irmParams = @{ Uri = $uploadUrl; Method = 'Put'; Headers = $uploadHeaders; Body = $chunkData; ContentType = "application/octet-stream"; ErrorAction = 'Stop' }
            Invoke-RestMethod @irmParams | Out-Null # Use Invoke-RestMethod directly to avoid verbose logging for every chunk
            $bytesUploaded += $bytesRead
        }
        Write-Host "" # Newline after progress bar
        Write-Log "⬆️ Uploaded large file '$($FileItem.Name)'"
        $global:bytesTransferred += $FileItem.Length
    }
    catch {
        Write-Host ""
        Write-Log "❌ Failed to upload chunk for '$($FileItem.Name)': $($_.Exception.Message)"
    }
    finally {
        if ($fileStream) { $fileStream.Close() }
    }
}

#==================================================================
# ✨ RECURSIVE COPY FUNCTION (No changes needed here) ✨
#==================================================================
function Copy-FilesToOneDrive {
    param(
        [Parameter(Mandatory=$true)][string]$CurrentLocalPath,
        [Parameter(Mandatory=$true)][string]$CurrentRemotePath
    )
    Write-Log "🔎 Processing local directory: '$CurrentLocalPath'"
    try {
        $localItems = Get-ChildItem -LiteralPath $CurrentLocalPath -ErrorAction Stop
        $localFolders = $localItems | Where-Object { $_.PSIsContainer }
        $localFiles = $localItems | Where-Object { -not $_.PSIsContainer }
        $global:filesScanned += $localFiles.Count
        $global:foldersScanned += $localFolders.Count
    } catch {
        Write-Log "❌ Could not access local path '$CurrentLocalPath'. Error: $($_.Exception.Message)"
        return
    }
    $encodedParentPath = ($CurrentRemotePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'

    # --- Step 1: Create all subfolders via batch request ---
    if ($localFolders.Count -gt 0) {
        $folderRequests = @()
        $requestId = 1
        foreach ($folder in $localFolders) {
            $folderRequest = [PSCustomObject]@{
                id      = "$($requestId++)"
                method  = "POST"
                url     = "/drives/$driveId/root:/$($encodedParentPath):/children"
                headers = @{ "Content-Type" = "application/json" }
                body    = @{
                    name                            = $folder.Name
                    folder                          = @{}
                    "@microsoft.graph.conflictBehavior" = "fail"
                }
            }
            $folderRequests += $folderRequest
        }
        
        $batchSize = 20
        for ($i = 0; $i -lt $folderRequests.Count; $i += $batchSize) {
            $chunk = $folderRequests[$i..[System.Math]::Min($i + $batchSize - 1, $folderRequests.Count - 1)]
            try {
                $batchResponses = Invoke-GraphBatchRequest -Requests $chunk -Headers $headers
                if ($null -ne $batchResponses) {
                    foreach($response in $batchResponses.responses) {
                        $originalRequest = $chunk | Where-Object { $_.id -eq $response.id } | Select-Object -First 1
                        $requestName = $originalRequest.body.name
                        if ($response.status -ge 200 -and $response.status -le 299) { Write-Log "✅ Created folder '$requestName' in '$CurrentRemotePath'" }
                        elseif ($response.status -eq 409) { Write-Log "➡️ Folder '$requestName' already exists. Continuing." }
                        else {
                            $errorMessage = if ($response.body.error) { $response.body.error.message } else { "Unknown Error" }
                            Write-Log "⚠️ Error creating folder '$requestName': $errorMessage (Status: $($response.status))"
                        }
                    }
                }
            } catch {
                Write-Log "❌ Major failure in batch folder creation: $($_.Exception.Message)"
            }
        }
    }

    # --- Step 2: Get list of remote files to avoid re-uploading ---
    $remoteFileNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $childrenUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$encodedParentPath`:/children?`$select=name,file"
        $irmParams = @{ Uri = $childrenUrl; Headers = $headers; Method = 'GET' }
        $remoteChildren = (Invoke-GraphApiRequestWithRetry -Splat $irmParams).value
        if ($null -ne $remoteChildren) {
           foreach($child in $remoteChildren) {
                if($child.file) { $remoteFileNames.Add($child.name) | Out-Null }
            }
        }
    } catch { Write-Log "⚠️ Could not list remote files in '$CurrentRemotePath'." }
    
    # --- Step 3: Upload local files that are not remote ---
    foreach ($file in $localFiles) {
        if ($remoteFileNames.Contains($file.Name)) {
            Write-Log "⏭️ Skipping '$($file.Name)' — already exists."
            continue
        }
        $fullRemoteFilePath = "$CurrentRemotePath/$($file.Name)"
        if ($file.Length -gt $LargeFileThreshold) {
            Upload-LargeFile -FileItem $file -FullRemotePath $fullRemoteFilePath -DriveId $driveId -Headers $headers
        } else {
            $encodedFullRemoteFilePath = ($fullRemoteFilePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
            $uploadUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$($encodedFullRemoteFilePath):/content?@microsoft.graph.conflictBehavior=fail"
            try {
                $fileBytes = [System.IO.File]::ReadAllBytes($file.FullName)
                $irmParams = @{
                    Uri         = $uploadUrl
                    Headers     = $headers
                    Method      = 'PUT'
                    Body        = $fileBytes
                    ContentType = 'application/octet-stream'
                }
                Invoke-GraphApiRequestWithRetry -Splat $irmParams | Out-Null
                $global:bytesTransferred += $file.Length
                Write-Log "⬆️ Uploaded '$($file.Name)'"
            } catch {
                if ($_.Exception.Response.StatusCode.value__ -eq 409) { Write-Log "⏭️ Skipping '$($file.Name)' — already exists." }
                else { Write-Log "❌ Failed to upload '$($file.Name)': $($_.Exception.Message)" }
            }
        }
    }

    # --- Step 4: Recurse into subdirectories ---
    foreach ($folder in $localFolders) {
        $newRemotePath = "$CurrentRemotePath/$($folder.Name)"
        Copy-FilesToOneDrive -CurrentLocalPath $folder.FullName -CurrentRemotePath $newRemotePath
    }
}

# =================================================================
# =================== SCRIPT EXECUTION STARTS HERE ==================
# =================================================================

# === GET DRIVE ID ===
try {
    Write-Log "🔍 Retrieving OneDrive drive ID for '$userPrincipalName'…"
    $driveUrl = "https://graph.microsoft.com/v1.0/users/$userPrincipalName/drive"
    $irmParams = @{ Uri = $driveUrl; Headers = $headers; Method = 'GET' }
    $driveResponse = Invoke-GraphApiRequestWithRetry -Splat $irmParams
    $driveId = $driveResponse.id
    Write-Log "✅ OneDrive drive ID found: $driveId"
}
catch {
    Write-Log "❌ Failed to retrieve OneDrive drive ID for '$userPrincipalName'."
    Write-Log "🔎 Error: $($_.Exception.Message)"
    # The detailed API error will have already been logged by the helper function
    exit
}

# === CREATE ROOT FOLDER ===
try {
    Write-Log "📂 Ensuring root folder on OneDrive exists: '$remoteFolder'"
    $createRootUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root/children"
    $folderBody = @{
        name                            = $remoteFolder
        folder                          = @{}
        "@microsoft.graph.conflictBehavior" = "fail"
    } | ConvertTo-Json -Depth 3
    $irmParams = @{ Uri = $createRootUrl; Headers = $headers; Method = 'POST'; Body = $folderBody; ContentType = "application/json" }
    Invoke-GraphApiRequestWithRetry -Splat $irmParams | Out-Null
}
catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 409) { # 409 Conflict
        Write-Log "➡️ Root folder '$remoteFolder' already exists. Continuing."
    } else {
        Write-Log "⚠️ Failed to create root folder: $($_.Exception.Message)"
        exit
    }
}

# === INITIALIZE COUNTERS AND START UPLOAD ===
$global:bytesTransferred = 0
$global:filesScanned = 0
$global:foldersScanned = 0

Write-Log "`n🚀 Starting migration process…"
$startTime = Get-Date

# This is the first and only call to the recursive function
Copy-FilesToOneDrive -CurrentLocalPath $localPath -CurrentRemotePath $remoteFolder

$endTime = Get-Date

# === SUMMARY ===
$duration = New-TimeSpan -Start $startTime -End $endTime
Write-Log "`n✅ Migration process finished!"
Write-Log "--------------------------------------------------"
Write-Log "📄 Files scanned: $global:filesScanned"
Write-Log "📁 Folders scanned: $global:foldersScanned"
Write-Log ("📦 Total data transferred: {0:N2} MB" -f ($global:bytesTransferred / 1MB))
Write-Log ("⏱️ Total time: {0:N0} minutes and {1} seconds" -f $duration.TotalMinutes, $duration.Seconds)
Write-Log "--------------------------------------------------"
Write-Log "📜 Full debug log saved to: $logFile"
