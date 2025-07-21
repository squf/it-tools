# This is the final / updated (and battle-tested in prod) version, this one works a lot better than previous iterations and avoids messy emtpy nested folder issues etc., and added logging to this version!
# a lot of work was done to get this stage of the script, mostly focused around avoiding API throttle limits, a lot of vry smrt API batching calls are being performed now to reduce API usage. Cool!
# I need to mention here that this ENTIRE THING only works because our Home Folders are named directly after our users, so their SAMAccountName / UPN in AD matches what their personal OneDrive URL will be
# e.g., \\homefolder\dir\FirstnameL -> will be equal to -> https://company-my.sharepoint.com/personal/FirstnameL_company_com <- which is how this entire thing works
# the very first line of this script prompts you to enter this SAMAccountName value first, which kicks off the entire rest of the thing
# so if your environment has mismatched UPN issues, or you don't name your Home Folders after your users SAMAccountName attributes, or anything else, this script is entirely useless for you!

# Begin Script --- Prompt for username and log directory, then upload files to OneDrive using Microsoft Graph API
# Requires: Registered Entra app to set $Auth.access_token (view readme)

$username = Read-Host "Enter the username (e.g., FirstnameL)"

#==================================================================
# ✨ SETUP AND VALIDATION ✨
#==================================================================

# === AUTHENTICATION DETAILS ===
$clientId = "<YOUR_CLIENTID_HERE>"
$clientSecret = "<YOUR_CLIENTSECRET_HERE>"
$tenantId = "<YOUR_TENANTID_HERE>"

# Global variable to hold the token and its expiry time
$global:AuthTokenInfo = @{}

# === LOGGING SETUP ===
$logDir = "C:\tmp\ODHF_Logs" # Logging location
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
$logFile = Join-Path $logDir "$username.txt"

function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

# === DEFINE PATHS ===
$baseLocalRoot     = "<\\YOUR_DATASERVER_LOCATION\HOMEFOLDER_DIR>" # Update this line to point to your UNC path in your environment, found in AD under a user's Home Directory attribute
$localPath         = Join-Path $baseLocalRoot $username
$userPrincipalName = "$($username)@company.com" # Update this line to match your company UPN format
$remoteFolder      = "Home Folder" # This is the root folder to be created in OneDrive
$LargeFileThreshold = 15 * 1024 * 1024 # 15 MB

# === AUTHENTICATION PLACEHOLDER ===
$headers = @{}

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
# ✨ API HELPER FUNCTIONS ✨
#==================================================================
function Invoke-GraphApiRequestWithRetry {
    param(
        [Parameter(Mandatory = $true)] [hashtable]$Splat,
        [int]$MaxRetries = 5,
        [int]$DefaultRetryAfterSeconds = 30
    )

    # === TOKEN REFRESH LOGIC ===
    # Check if the token is missing or is about to expire
    if (-not $global:AuthTokenInfo.AccessToken -or (Get-Date) -ge $global:AuthTokenInfo.ExpiresOn) {
        Get-NewGraphToken
    }
    
    # Add/update the authorization header in the request
    $Splat.Headers.Authorization = "Bearer $($global:AuthTokenInfo.AccessToken)"
    # === END TOKEN REFRESH LOGIC ===

    $retryCount = 0
    while ($true) {
        try {
            return Invoke-RestMethod @Splat
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $errorResponse = $_.Exception.Response
            # If we get a 401, our token might be stale despite our check. Force a refresh and retry once.
            if ($errorResponse.StatusCode.value__ -eq 401 -and $retryCount -eq 0) {
                Write-Log "⚠️ Received 401 Unauthorized. Forcing token refresh and retrying the call once."
                $retryCount++
                Get-NewGraphToken
                $Splat.Headers.Authorization = "Bearer $($global:AuthTokenInfo.AccessToken)"
                continue # Go to the top of the while loop to retry the API call
            }
            
            # (The rest of the existing 429 throttling logic stays here)
            if ($errorResponse.StatusCode.value__ -eq 429 -and $retryCount -lt $MaxRetries) {
                $retryCount++
                $retryAfterHeader = $errorResponse.Headers['Retry-After']
                $waitTimeSeconds = $DefaultRetryAfterSeconds
                if ($null -ne $retryAfterHeader) {
                    if (-not ([int]::TryParse($retryAfterHeader, [ref]$waitTimeSeconds))) {
                        try {
                            $retryDate = [datetimeoffset]::Parse($retryAfterHeader, [System.Globalization.CultureInfo]::InvariantCulture)
                            $secondsToWait = ($retryDate - [datetimeoffset]::UtcNow).TotalSeconds
                            if ($secondsToWait -gt 0) { $waitTimeSeconds = [math]::Ceiling($secondsToWait) }
                        } catch { Write-Log "⚠️ Could not parse Retry-After date header." }
                    }
                }
                if ($waitTimeSeconds -gt 300) { $waitTimeSeconds = 300 }
                if ($waitTimeSeconds -le 0) { $waitTimeSeconds = 1 }
                Write-Log "⏳ API throttled (429). Retrying in $waitTimeSeconds seconds... (Attempt $retryCount of $MaxRetries)"
                Start-Sleep -Seconds $waitTimeSeconds
            }
            else { throw }
        }
        catch { throw }
    }
}

function Invoke-GraphBatchRequest {
    param(
        [Parameter(Mandatory=$true)] [array]$Requests,
        [Parameter(Mandatory=$true)] [hashtable]$Headers
    )
    if ($Requests.Count -eq 0) { return }
    $batchUrl = "https://graph.microsoft.com/v1.0/`$batch"
    $batchPayload = @{ requests = $Requests }
    $batchJsonBody = $batchPayload | ConvertTo-Json -Depth 10

    $irmParams = @{
        Uri         = $batchUrl
        Headers     = $Headers
        Method      = 'POST'
        Body        = $batchJsonBody
        ContentType = "application/json"
    }
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
            $irmParams = @{ Uri = $uploadUrl; Method = 'Put'; Headers = $uploadHeaders; Body = $chunkData; ContentType = "application/octet-stream"; ErrorAction = 'Stop' }
            Invoke-GraphApiRequestWithRetry -Splat $irmParams | Out-Null
            $bytesUploaded += $bytesRead
        }
        Write-Host ""
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

function Get-NewGraphToken {
    Write-Log "🔄 Refreshing API access token..."
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $tokenBody = @{
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }

    try {
        $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
        $global:AuthTokenInfo.AccessToken = $tokenResponse.access_token
        # Set expiry to 5 minutes before it actually expires, for a safe buffer
        $global:AuthTokenInfo.ExpiresOn = (Get-Date).AddSeconds($tokenResponse.expires_in - 300)
        Write-Log "✅ New token acquired. Valid until $($global:AuthTokenInfo.ExpiresOn.ToString('T'))"
    }
    catch {
        Write-Log "❌ FATAL: Could not get new access token. Error: $($_.Exception.Message)"
        throw
    }
}

#==================================================================
# ✨ RECURSIVE COPY FUNCTION ✨
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
                id      = $requestId.ToString() 
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
            $requestId++
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

    # --- Step 2: Get list of remote files, with retries for 404 errors ---
    $remoteFileNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $listRetries = 3
    for ($attempt = 1; $attempt -le $listRetries; $attempt++) {
        try {
            $childrenUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$encodedParentPath`:/children?`$select=name,file"
            $irmParams = @{ Uri = $childrenUrl; Headers = $headers; Method = 'GET' }
            $remoteChildren = (Invoke-GraphApiRequestWithRetry -Splat $irmParams).value
            if ($null -ne $remoteChildren) {
                foreach($child in $remoteChildren) {
                    if($child.file) { $remoteFileNames.Add($child.name) | Out-Null }
                }
            }
            break # Success, so we exit the retry loop
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            if ($_.Exception.Response.StatusCode.value__ -eq 404 -and $attempt -lt $listRetries) {
                # This is a 404 error and we can still retry.
                Write-Log "⏳ Path not found (404), likely a replication delay. Retrying in 3 seconds... (Attempt $attempt of $listRetries)"
                Start-Sleep -Seconds 3
            } else {
                # This is a different error, or the last retry failed. Log and break.
                Write-Log "⚠️ Could not list remote files in '$CurrentRemotePath'. Error: $($_.Exception.Message)"
                break 
            }
        }
        catch {
            # A non-API error occurred. Log and break.
            Write-Log "⚠️ Could not list remote files in '$CurrentRemotePath'. Unhandled Error: $($_.Exception.Message)"
            break
        }
    }
    
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
# =================== SCRIPT EXECUTION STARTS HERE ================
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
