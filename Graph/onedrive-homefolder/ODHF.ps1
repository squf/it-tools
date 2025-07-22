# Begin Script --- OneDrive Home Folder Migration
# Requires: Registered Entra app to set $Auth.access_token (view readme)
# Update lines: 12, 13, 14, 352 & 354 to work in your environment

$username = Read-Host "Enter the username (e.g., FirstnameL)"

#==================================================================
# ✨ SETUP AND CONFIGURATION ✨
#==================================================================

# === AUTHENTICATION DETAILS ===
$clientId     = "<YOUR-CLIENT-ID-HERE>" # UPDATE THIS LINE
$clientSecret = "<YOUR-CLIENT-SECRET-HERE>" # UPDATE THIS LINE
$tenantId     = "<YOUR-TENANT-ID-HERE>" # UPDATE THIS LINE

# Global variable to hold the token and its expiry time
$global:AuthTokenInfo = @{}

# Global variables to track API Rate Limits
$global:RateLimit = @{
    Limit     = 'N/A'
    Remaining = 'N/A'
    Reset     = 'N/A'
}

#==================================================================
# ✨ FUNCTION DEFINITIONS ✨
#==================================================================

function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
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

function Update-RateLimitStatus {
    param ([hashtable]$Headers)

    if ($Headers.'RateLimit-Limit') { $global:RateLimit.Limit = $Headers.'RateLimit-Limit' }
    if ($Headers.'RateLimit-Remaining') { $global:RateLimit.Remaining = [int]$Headers.'RateLimit-Remaining' }
    if ($Headers.'RateLimit-Reset') { $global:RateLimit.Reset = $Headers.'RateLimit-Reset' }
}

function Invoke-GraphApiRequestWithRetry {
    param(
        [Parameter(Mandatory = $true)] [hashtable]$Splat,
        [int]$MaxRetries = 5,
        [int]$DefaultRetryAfterSeconds = 30
    )

    # === TOKEN REFRESH LOGIC ===
    if (-not $global:AuthTokenInfo.AccessToken -or (Get-Date) -ge $global:AuthTokenInfo.ExpiresOn) {
        Get-NewGraphToken
    }
    $Splat.Headers.Authorization = "Bearer $($global:AuthTokenInfo.AccessToken)"
    # === END TOKEN REFRESH LOGIC ===

    $retryCount = 0
    while ($true) {
        try {
            $responseHeaders = $null
            $response = Invoke-RestMethod @Splat -ResponseHeadersVariable responseHeaders
            Update-RateLimitStatus -Headers $responseHeaders
            return $response
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $errorResponse = $_.Exception.Response
            Update-RateLimitStatus -Headers $errorResponse.Headers
            if ($errorResponse.StatusCode.value__ -eq 401 -and $retryCount -eq 0) {
                Write-Log "⚠️ Received 401 Unauthorized. Forcing token refresh and retrying the call once."
                $retryCount++
                Get-NewGraphToken
                $Splat.Headers.Authorization = "Bearer $($global:AuthTokenInfo.AccessToken)"
                continue
            }
            
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

function Copy-FilesToOneDrive {
    param(
        [Parameter(Mandatory=$true)][string]$CurrentLocalPath,
        [Parameter(Mandatory=$true)][string]$CurrentRemotePath
    )
    Write-Log "🔎 Processing local directory: '$CurrentLocalPath'"
    # Check the remaining API quota before processing the folder
    if ($global:RateLimit.Remaining -is [int] -and $global:RateLimit.Remaining -lt 200) { # Using 200 as a safe buffer
        $resetSeconds = $global:RateLimit.Reset
        Write-Log "⚠️ WARNING: API quota is low ($($global:RateLimit.Remaining) remaining). Pausing script for $resetSeconds seconds until quota resets..."
        Start-Sleep -Seconds $resetSeconds
        try {
            $checkUri = "https://graph.microsoft.com/v1.0/users?`$top=1&`$select=id"
            Invoke-GraphApiRequestWithRetry -Splat @{ Uri = $checkUri; Headers = $headers; Method = 'GET' } | Out-Null
            Write-Log "✅ API quota has been reset. Resuming migration."
        } catch { Write-Log "⚠️ Resuming migration, but could not confirm new quota." }
    }
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

    # Step 1: Create all subfolders via batch request
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

    # Step 2: Get list of remote files, with retries for 404 errors
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
            break
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            if ($_.Exception.Response.StatusCode.value__ -eq 404 -and $attempt -lt $listRetries) {
                Write-Log "⏳ Path not found (404), likely a replication delay. Retrying in 3 seconds... (Attempt $attempt of $listRetries)"
                Start-Sleep -Seconds 3
            } else {
                Write-Log "⚠️ Could not list remote files in '$CurrentRemotePath'. Error: $($_.Exception.Message)"
                break 
            }
        }
        catch {
            Write-Log "⚠️ Could not list remote files in '$CurrentRemotePath'. Unhandled Error: $($_.Exception.Message)"
            break
        }
    }
    
    # Step 3: Upload local files that are not remote
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

    # Step 4: Recurse into subdirectories
    foreach ($folder in $localFolders) {
        $newRemotePath = "$CurrentRemotePath/$($folder.Name)"
        Copy-FilesToOneDrive -CurrentLocalPath $folder.FullName -CurrentRemotePath $newRemotePath
    }
}

#==================================================================
# ✨ SCRIPT EXECUTION ✨
#==================================================================

# === LOGGING, PATHS, AND PRE-CHECKS ===
$logDir = "C:\tmp\ODHF_Logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
$logFile = Join-Path $logDir "$username.txt"

$baseLocalRoot    = "\\<YOUR-DATA-SERVER>\<YOUR-HOME-FOLDERS-DIR" # UPDATE THIS LINE
$localPath        = Join-Path $baseLocalRoot $username
$userPrincipalName = "$($username)@COMPANY.com" # UPDATE THIS LINE
$remoteFolder     = "Home Folder"
$LargeFileThreshold = 15 * 1024 * 1024 # 15 MB
$headers = @{}

if (-not (Test-Path -LiteralPath $localPath)) {
    Write-Log "❌ Local folder not found: $localPath. Please check the username and network path."
    exit
}

try {
    Write-Log "`n📊 Checking initial API rate limits..."
    $checkUri = "https://graph.microsoft.com/v1.0/users?`$top=1&`$select=id"
    Invoke-GraphApiRequestWithRetry -Splat @{ Uri = $checkUri; Headers = $headers; Method = 'GET' } | Out-Null
    Write-Log "--------------------------------------------------"
    Write-Log "Current API Quota Remaining: $($global:RateLimit.Remaining) / $($global:RateLimit.Limit)"
    Write-Log "--------------------------------------------------"
} catch {
    # This catch block needs to be updated to show the real error
    Write-Log "⚠️ Could not check initial rate limits. Full error: $($_.Exception.Message)"
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
Write-Log ("📦 Total data transferred: {0:N2} MB" -f ($global:BytesTransferred / 1MB))
Write-Log ("⏱️ Total time: {0:N0} minutes and {1} seconds" -f $duration.TotalMinutes, $duration.Seconds)
Write-Log "--------------------------------------------------"
