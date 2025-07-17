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
# This function wraps Invoke-RestMethod to handle 429 (throttling) errors automatically.
#==================================================================
function Invoke-GraphApiRequestWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Splat,
        [int]$MaxRetries = 5,
        [int]$DefaultRetryAfterSeconds = 30 # Default wait time as requested
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
                # so the original script's error handling can take over.
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
$baseLocalRoot = "\\<YOUR_DATA_SERVER>\<YOUR_HOMEFOLDERS_DIR>" # UPDATE THIS LINE TO WORK IN YOUR ENVIRONMENT BTW :) this is just whatever server location you host all the user's home folders on, you can find this in the HomeDirectory Attrib. in AD if you don't know
$localPath = Join-Path $baseLocalRoot $username

# Validate local folder exists
if (-not (Test-Path -LiteralPath $localPath)) {
    Write-Log "❌ Local folder not found: $localPath"
    exit
}

# Construct OneDrive user ID and remote path
$remoteUserId = $username.ToLower() -replace '[^a-z0-9]', ''
$remoteFolder = "Home Folder"
$remotePath = "$remoteFolder"

# Confirm before proceeding
Write-Log "`n🧾 Summary:"
Write-Log "📁 Local path: $localPath"
Write-Log "📂 OneDrive target folder: $remotePath"
$confirm = Read-Host "`nProceed with upload? (Y/N)"
if ($confirm -ne "Y") {
    Write-Log "❌ Operation cancelled."
    exit
}

#=== AUTH TOKEN ===
# Assumes $Auth.access_token is already available from get-token.ps1
if (-not $Auth.access_token) {
    Write-Log "❌ Auth token not found in `$Auth.accesstoken. Please run your authentication script first."
    exit
}
$headers = @{ Authorization = "Bearer $($Auth.access_token)" }


#=== GET DRIVE ID ===
$driveUrl = "https://graph.microsoft.com/v1.0/users/${remoteUserId}@imcu.com/drive"
try {
    Write-Log "🔍 Retrieving OneDrive drive ID…"
    # ✨ MODIFIED - Use retry function
    $irmParams = @{
        Uri = $driveUrl
        Headers = $headers
        Method = 'GET'
    }
    $driveResponse = Invoke-GraphApiRequestWithRetry -Splat $irmParams
    $driveId = $driveResponse.id
    Write-Log "✅ OneDrive drive ID: $driveId"
}
catch {
    Write-Log "❌ Failed to retrieve OneDrive drive ID."
    Write-Log "🔎 Error: $($_.Exception.Message)"
    exit
}

#=== CREATE ROOT FOLDER ===
# URL-encode the root folder name
$encodedRootFolder = [uri]::EscapeDataString($remoteFolder)
$createRootUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root/children"
$folderBody = @{
    name = $remoteFolder
    folder = @{}
    "@microsoft.graph.conflictBehavior" = "fail" # Fail if folder already exists
} | ConvertTo-Json -Depth 3

try {
    Write-Log "📂 Creating root folder on OneDrive: '$remoteFolder'"
    # ✨ - Use retry function
    $irmParams = @{
        Uri = $createRootUrl
        Headers = $headers
        Method = 'POST'
        Body = $folderBody
        ContentType = "application/json"
    }
    Invoke-GraphApiRequestWithRetry -Splat $irmParams | Out-Null
}
catch {
    if ($_.Exception.Response.StatusCode -eq 'Conflict' -or $_.Exception.Message -match "nameAlreadyExists") {
        Write-Log "➡️ Root folder '$remoteFolder' already exists. Continuing."
    }
    else {
        Write-Log "⚠️ Failed to create root folder: $($_.Exception.Message)"
    }
}


#=== UPLOAD FUNCTIONS ===
$LargeFileThreshold = 4 * 1024 * 1024 # 4MB

function Upload-LargeFile {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$FileItem,
        [Parameter(Mandatory = $true)][string]$FullRemotePath,
        [Parameter(Mandatory = $true)][string]$DriveId,
        [Parameter(Mandatory = $true)][hashtable]$Headers
    )

    # Fallback: Custom Graph API upload session method
    $encodedFullRemoteFilePath = ($FullRemotePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $sessionUrl = "https://graph.microsoft.com/v1.0/drives/$DriveId/root:/$($encodedFullRemoteFilePath):/createUploadSession"
    $sessionBody = @{ item = @{ "@microsoft.graph.conflictBehavior" = "rename" } } | ConvertTo-Json

    try {
        Write-Log "Creating upload session for '$($FileItem.Name)'..."
        # ✨ - Use retry function
        $irmParams = @{
            Uri = $sessionUrl
            Headers = $Headers
            Method = 'POST'
            Body = $sessionBody
            ContentType = "application/json"
        }
        $sessionResponse = Invoke-GraphApiRequestWithRetry -Splat $irmParams
        $uploadUrl = $sessionResponse.uploadUrl
    }
    catch {
        Write-Log "❌ Failed to create upload session for '$($FileItem.Name)': $($_.Exception.Message)"
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

            # Show progress
            $newProgress = [math]::Round(($endRange + 1) / $totalBytes * 100)
            if ($newProgress -gt $progress) {
                $progress = $newProgress
                Write-Host "`rUploading '$($FileItem.Name)': $progress% " -NoNewline
            }

            # ✨ MODIFIED - Use retry function for each chunk
            $irmParams = @{
                Uri = $uploadUrl
                Method = 'Put'
                Headers = $uploadHeaders
                Body = $chunkData
                ContentType = "application/octet-stream"
                ErrorAction = 'Stop'
            }
            Invoke-GraphApiRequestWithRetry -Splat $irmParams
            $bytesUploaded += $bytesRead
        }

        Write-Host "" # Newline after progress bar
        Write-Log "⬆️ Uploaded large file '$($FileItem.Name)'"
        $global:size += $FileItem.Length
    }
    catch {
        Write-Host "" # Newline after progress bar
        Write-Log "❌ Failed to upload chunk for '$($FileItem.Name)': $($_.Exception.Message)"
    }
    finally {
        if ($fileStream) { $fileStream.Close() }
    }
}

function Copy-FilesToOneDrive ($localPath, $remotePath) {
    try {
        $items = Get-ChildItem -LiteralPath $localPath -ErrorAction Stop
    }
    catch {
        Write-Log "❌ Could not access local path '$localPath'. Error: $($_.Exception.Message)"
        return
    }
    $CountFiles = ($items | Where-Object { -not $_.PSIsContainer }).Count
    $CountFolders = ($items | Where-Object { $_.PSIsContainer }).Count

    Write-Log "📁 Scanning '$localPath' (folders/files: $CountFolders/$CountFiles)"

    $encodedParentPath = ($remotePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'

    foreach ($item in $items) {
        if ($item.PSIsContainer) {
            $newRemotePath = "$remotePath/$($item.Name)"
            $folderUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/${encodedParentPath}:/children"
            $folderBody = @{
                name = $item.Name
                folder = @{}
                "@microsoft.graph.conflictBehavior" = "fail"
            } | ConvertTo-Json -Depth 3

            try {
                # ✨ - Use retry function
                $irmParams = @{
                    Uri = $folderUrl
                    Headers = $headers
                    Method = 'POST'
                    Body = $folderBody
                    ContentType = "application/json"
                }
                Invoke-GraphApiRequestWithRetry -Splat $irmParams | Out-Null
            }
            catch {
                if ($_.Exception.Response.StatusCode -eq 'Conflict' -or $_.Exception.Message -match "nameAlreadyExists") {
                    Write-Log "➡️ Folder '$($item.Name)' already exists in '$remotePath'. Continuing."
                }
                else {
                    Write-Log "⚠️ Could not create folder '$newRemotePath': $($_.Exception.Message)"
                }
            }
            Copy-FilesToOneDrive -localPath $item.FullName -remotePath $newRemotePath
        }
        else { # It's a file
            $fullRemoteFilePath = "$remotePath/$($item.Name)"
            $encodedFullRemoteFilePath = ($fullRemoteFilePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'

            # Check if file already exists
            $checkUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$encodedFullRemoteFilePath"
            try {
                # ✨ - Use retry function
                $irmParams = @{
                    Uri = $checkUrl
                    Headers = $headers
                    Method = 'GET'
                    ErrorAction = 'Stop'
                }
                Invoke-GraphApiRequestWithRetry -Splat $irmParams | Out-Null
                Write-Log "⏭️ Skipping '$($item.Name)' — already exists in OneDrive."
                continue
            }
            catch {
                if ($_.Exception.Response.StatusCode -ne 'NotFound') {
                    Write-Log "⚠️ Error checking if file '$($item.Name)' exists: $($_.Exception.Message)"
                }
            }

            # Decide on upload method based on size
            if ($item.Length -gt $LargeFileThreshold) {
                Write-Log "📦 File '$($item.Name)' is large ($([math]::Round($item.Length / 1MB, 2)) MB). Using large file upload process."
                Upload-LargeFile -FileItem $item -FullRemotePath $fullRemoteFilePath -DriveId $driveId -Headers $headers
            }
            else {
                # Use simple upload for small files
                $uploadUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$($encodedFullRemoteFilePath):/content"
                try {
                    # ✨ - Use retry function
                    $irmParams = @{
                        Uri = $uploadUrl
                        Headers = $headers
                        Method = 'PUT'
                        InFile = $item.FullName
                        ContentType = "application/octet-stream"
                    }
                    Invoke-GraphApiRequestWithRetry -Splat $irmParams | Out-Null
                    $global:size += $item.Length
                    Write-Log "⬆️ Uploaded '$($item.Name)' to '$remotePath'"
                }
                catch {
                    Write-Log "❌ Failed to upload '$($item.Name)': $($_.Exception.Message)"
                }
            }
        }
    }
}

# Initialize counters
$global:size = 0
$global:AllFiles = 0
$global:AllFolders = 0

# Start upload
Write-Log "`n🚀 Starting upload process…"
Copy-FilesToOneDrive -localPath $localPath -remotePath $remotePath

# Summary
Write-Log "`n✅ Upload complete!"
Write-Log "📄 Files scanned: $global:AllFiles"
Write-Log "📁 Folders scanned: $global:AllFolders"
Write-Log ("📦 Bytes transferred: {0:N0}" -f $global:Size)
