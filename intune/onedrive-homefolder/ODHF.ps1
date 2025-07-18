# This is the final / updated version of the script I built, this one works a lot better than previous iterations and avoids messy emtpy nested folder issues etc., and added logging to this version!
# I need to mention here that this ENTIRE THING only works because our Home Folders are named directly after our users, so their SAMAccountName in AD matches what their personal OneDrive URL will be
# e.g., \\homefolder\dir\FirstnameL -> will be equal to -> https://company-my.sharepoint.com/personal/FirstnameL_company_com <- which is how this entire thing works
# the very first line of this script prompts you to enter this SAMAccountName value first, which kicks off the entire rest of the thing
# so if your environment has mismatched UPN issues, or you don't name your Home Folders after your users SAMAccountName attributes, or anything else, this script is entirely useless for you!

# Begin Script --- Prompt for username and log directory, then upload files to OneDrive using Microsoft Graph API
# Requires: get-token.ps1 to be run first to set $Auth.access_token

$username = Read-Host "Enter the username (e.g., FirstnameL)"
#=== LOGGING SETUP ===
$logDir = "C:\tmp\ODHF_Logs" # it just spits out a log file to here, named after whatever you entered above for the user, e.g. (C:\tmp\ODHFLogs\FirstnameL.txt)
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
$logFile = Join-Path $logDir "$username.txt"
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

#==================================================================
# ✨ THROTTLE HANDLING FUNCTION ✨
# This function wraps Invoke-RestMethod to handle HTTP 429 (throttling) errors automatically.
#==================================================================
function Invoke-GraphApiRequestWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Splat,
        [int]$MaxRetries = 5,
        [int]$DefaultRetryAfterSeconds = 30
    )

    $retryCount = 0
    while ($true) {
        try {
            # Pass the splatted hashtable to Invoke-RestMethod
            return Invoke-RestMethod @Splat
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            # Check for HTTP 429 "Too Many Requests"
            if ($_.Exception.Response.StatusCode.value__ -eq 429 -and $retryCount -lt $MaxRetries) {
                $retryCount++
                $retryAfterHeader = $_.Exception.Response.Headers['Retry-After']
                $waitTimeSeconds = $DefaultRetryAfterSeconds

                # If the API provides a Retry-After header, use it.
                if ($null -ne $retryAfterHeader) {
                    if (-not ([int]::TryParse($retryAfterHeader, [ref]$waitTimeSeconds))) {
                        try {
                            # Handle HTTP-date format
                            $retryDate = [datetimeoffset]::Parse($retryAfterHeader, [System.Globalization.CultureInfo]::InvariantCulture)
                            $secondsToWait = ($retryDate - [datetimeoffset]::UtcNow).TotalSeconds
                            if ($secondsToWait -gt 0) {
                                $waitTimeSeconds = [math]::Ceiling($secondsToWait)
                            }
                        }
                        catch {
                            Write-Log "⚠️ Could not parse Retry-After date header. Using default wait time."
                            $waitTimeSeconds = $DefaultRetryAfterSeconds
                        }
                    }
                }

                # Cap max wait time to 5 minutes
                if ($waitTimeSeconds -gt 300) { $waitTimeSeconds = 300 }
                if ($waitTimeSeconds -le 0) { $waitTimeSeconds = 1 } # Must wait at least 1 second

                Write-Log "⚠️ API throttled (429). Retrying in $waitTimeSeconds seconds... (Attempt $retryCount of $MaxRetries)"
                Start-Sleep -Seconds $waitTimeSeconds
            }
            else {
                # For other HTTP errors or if max retries are exceeded, re-throw the exception
                throw
            }
        }
        catch {
            # For non-HTTP exceptions, re-throw immediately.
            throw
        }
    }
}


# Define base local path
$baseLocalRoot = "\\<YOUR_DATA_SERVER>\<YOUR_HOMEFOLDERS_DIR>" # UPDATE THIS LINE TO WORK IN YOUR ENVIRONMENT BTW :)
$localPath = Join-Path $baseLocalRoot $username

# Validate local folder exists
if (-not (Test-Path -LiteralPath $localPath)) {
    Write-Log "❌ Local folder not found: $localPath"
    exit
}

# Construct OneDrive user ID and remote path
# omg, make sure this matches ur upn format
$userPrincipalName = "$($username)@company.com" 
$remoteFolder = "Home Folder"
$remotePath = "$remoteFolder"

# Confirm before proceeding
Write-Log "`n🧾 Summary:"
Write-Log "📁 Local path: $localPath"
Write-Log "👤 User Principal Name: $userPrincipalName"
Write-Log "📂 OneDrive target folder: $remotePath"
$confirm = Read-Host "`nProceed with upload? (Y/N)"
if ($confirm -ne "Y") {
    Write-Log "❌ Operation cancelled."
    exit
}

# === AUTH TOKEN ===
if (-not $Auth.access_token) {
    Write-Log "❌ Auth token not found in `$Auth.access_token. Please run your authentication script first."
    exit
}
$headers = @{ Authorization = "Bearer $($Auth.access_token)" }


# === GET DRIVE ID ===
$driveUrl = "https://graph.microsoft.com/v1.0/users/$userPrincipalName/drive"
try {
    Write-Log "🔍 Retrieving OneDrive drive ID…"
    $irmParams = @{ Uri = $driveUrl; Headers = $headers; Method = 'GET' }
    $driveResponse = Invoke-GraphApiRequestWithRetry -Splat $irmParams
    $driveId = $driveResponse.id
    Write-Log "✅ OneDrive drive ID: $driveId"
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
        name = $remoteFolder
        folder = @{}
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


# === UPLOAD FUNCTIONS (Large file upload is unchanged) ===
$LargeFileThreshold = 4 * 1024 * 1024 # 4MB

function Upload-LargeFile {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$FileItem,
        [Parameter(Mandatory = $true)][string]$FullRemotePath,
        [Parameter(Mandatory = $true)][string]$DriveId,
        [Parameter(Mandatory = $true)][hashtable]$Headers
    )

    $encodedFullRemoteFilePath = ($FullRemotePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $sessionUrl = "https://graph.microsoft.com/v1.0/drives/$DriveId/root:/$($encodedFullRemoteFilePath):/createUploadSession"
    # use 'fail' to avoid re-uploading existing files, change to 'replace' or 'rename' if u want different behavior
    $sessionBody = @{ item = @{ "@microsoft.graph.conflictBehavior" = "fail" } } | ConvertTo-Json

    try {
        Write-Log "Creating upload session for '$($FileItem.Name)'..."
        $irmParams = @{ Uri = $sessionUrl; Headers = $Headers; Method = 'POST'; Body = $sessionBody; ContentType = "application/json" }
        $sessionResponse = Invoke-GraphApiRequestWithRetry -Splat $irmParams
        $uploadUrl = $sessionResponse.uploadUrl
    }
    catch {
        # if the file already exists, the session creation will fail with a 409 conflict
        if ($_.Exception.Response.StatusCode.value__ -eq 409) {
            Write-Log "⏭️ Skipping large file '$($FileItem.Name)' — already exists."
        } else {
            Write-Log "❌ Failed to create upload session for '$($FileItem.Name)': $($_.Exception.Message)"
        }
        return
    }

    $chunkSize = 5 * 1024 * 1024 # 5 MB upload chunks
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
            Invoke-GraphApiRequestWithRetry -Splat $irmParams
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

#==================================================================
# ✨ BATCH REQUEST FUNCTION ✨
# this little guy bundles up all our folder requests
#==================================================================
function Invoke-GraphBatchRequest {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Requests,
        [Parameter(Mandatory=$true)]
        [hashtable]$Headers
    )
    
    if ($Requests.Count -eq 0) { return }

    $batchUrl = "https://graph.microsoft.com/v1.0/`$batch"
    $batchBody = @{ requests = $Requests } | ConvertTo-Json -Depth 10

    $irmParams = @{ Uri = $batchUrl; Headers = $Headers; Method = 'POST'; Body = $batchBody; ContentType = "application/json" }
    
    try {
        Write-Log "📦 Sending batch request with $($Requests.Count) operations..."
        $response = Invoke-GraphApiRequestWithRetry -Splat $irmParams
        return $response.responses
    } catch {
        Write-Log "❌ Major failure in batch request: $($_.Exception.Message)"
        return $null
    }
}

#==================================================================
# ✨ recursive copy function ✨
# this is where all the magic happens
#==================================================================
function Copy-FilesToOneDrive {
    param(
        [Parameter(Mandatory=$true)][string]$CurrentLocalPath,
        [Parameter(Mandatory=$true)][string]$CurrentRemotePath
    )

    Write-Log "🔎 Processing local directory: '$CurrentLocalPath'"
    
    try {
        $localItems = Get-ChildItem -LiteralPath $CurrentLocalPath -ErrorAction Stop
    } catch {
        Write-Log "❌ Could not access local path '$CurrentLocalPath'. Error: $($_.Exception.Message)"
        return
    }

    $localFolders = $localItems | Where-Object { $_.PSIsContainer }
    $localFiles = $localItems | Where-Object { -not $_.PSIsContainer }
    $global:filesScanned += $localFiles.Count
    $global:foldersScanned += $localFolders.Count
    
    $encodedParentPath = ($CurrentRemotePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'

    # --- Step 1: Create all subfolders in this directory using a batch request ---
    if ($localFolders.Count -gt 0) {
        $folderRequests = @()
        $requestId = 1
        foreach ($folder in $localFolders) {
            $folderRequest = @{
                id = "$($requestId++)"
                method = "POST"
                url = "/drives/$driveId/root:/$($encodedParentPath):/children"
                headers = @{ "Content-Type" = "application/json" }
                body = @{
                    name = $folder.Name
                    folder = @{}
                    "@microsoft.graph.conflictBehavior" = "fail"
                }
            }
            $folderRequests += $folderRequest
        }

        # The Graph API allows a maximum of 20 requests per batch.
        $batchSize = 20
        for ($i = 0; $i -lt $folderRequests.Count; $i += $batchSize) {
            $chunk = $folderRequests[$i..[System.Math]::Min($i + $batchSize - 1, $folderRequests.Count - 1)]
            $batchResponses = Invoke-GraphBatchRequest -Requests $chunk -Headers $headers
            
            # log results of the batch
            foreach($response in $batchResponses) {
                $requestName = $chunk[[int]$response.id - 1].body.name
                if ($response.status -ge 200 -and $response.status -le 299) {
                    Write-Log "✅ Created folder '$requestName' in '$CurrentRemotePath'"
                } elseif ($response.status -eq 409) { # 409 Conflict
                     Write-Log "➡️ Folder '$requestName' already exists. Continuing."
                } else {
                    Write-Log "⚠️ Error creating folder '$requestName': $($response.body.error.message)"
                }
            }
        }
    }

    # --- Step 2: Get a list of remote files to avoid re-uploading ---
    $remoteFileNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $childrenUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$encodedParentPath:/children?`$select=name,file"
        $irmParams = @{ Uri = $childrenUrl; Headers = $headers; Method = 'GET' }
        $remoteChildren = (Invoke-GraphApiRequestWithRetry -Splat $irmParams).value
        # only add items that are files to our hashset
        foreach($child in $remoteChildren){
            if($child.file){ $remoteFileNames.Add($child.name) | Out-Null }
        }
    } catch {
        Write-Log "⚠️ Could not list remote files in '$CurrentRemotePath'. May re-upload files. Error: $($_.Exception.Message)"
    }
    
    # --- Step 3: Upload any local files that are not on the remote ---
    foreach ($file in $localFiles) {
        if ($remoteFileNames.Contains($file.Name)) {
            Write-Log "⏭️ Skipping '$($file.Name)' — already exists in OneDrive."
            continue
        }

        $fullRemoteFilePath = "$CurrentRemotePath/$($file.Name)"
        if ($file.Length -gt $LargeFileThreshold) {
            Write-Log "📦 File '$($file.Name)' is large ($([math]::Round($file.Length / 1MB, 2)) MB). Using large file upload process."
            Upload-LargeFile -FileItem $file -FullRemotePath $fullRemoteFilePath -DriveId $driveId -Headers $headers
        } else {
            # Simple upload for small files
            $encodedFullRemoteFilePath = ($fullRemoteFilePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
            $uploadUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$($encodedFullRemoteFilePath):/content"
            try {
                $irmParams = @{ Uri = $uploadUrl; Headers = $headers; Method = 'PUT'; InFile = $file.FullName; ContentType = "application/octet-stream" }
                Invoke-GraphApiRequestWithRetry -Splat $irmParams | Out-Null
                $global:bytesTransferred += $file.Length
                Write-Log "⬆️ Uploaded '$($file.Name)' to '$CurrentRemotePath'"
            }
            catch {
                # A 409 here would be unexpected since we already checked, but handle it just in case
                if ($_.Exception.Response.StatusCode.value__ -eq 409) {
                    Write-Log "⏭️ Skipping '$($file.Name)' — already exists (detected during upload)."
                } else {
                    Write-Log "❌ Failed to upload '$($file.Name)': $($_.Exception.Message)"
                }
            }
        }
    }
    
    # --- Step 4: Recurse into subdirectories ---
    foreach ($folder in $localFolders) {
        $newRemotePath = "$CurrentRemotePath/$($folder.Name)"
        Copy-FilesToOneDrive -CurrentLocalPath $folder.FullName -CurrentRemotePath $newRemotePath
    }
}


# Initialize counters
$global:bytesTransferred = 0
$global:filesScanned = 0
$global:foldersScanned = 0

# Start upload
Write-Log "`n🚀 Starting upload process…"
$startTime = Get-Date
Copy-FilesToOneDrive -CurrentLocalPath $localPath -CurrentRemotePath $remotePath
$endTime = Get-Date

# Summary
$duration = New-TimeSpan -Start $startTime -End $endTime
Write-Log "`n✅ Upload process finished!"
Write-Log "📄 Files scanned: $global:filesScanned"
Write-Log "📁 Folders scanned: $global:foldersScanned"
Write-Log ("📦 Total bytes transferred: {0:N2} MB" -f ($global:bytesTransferred / 1MB))
Write-Log ("⏱️ Total time: {0:N0} minutes and {1} seconds" -f $duration.TotalMinutes, $duration.Seconds)
