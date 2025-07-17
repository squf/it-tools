# This is the final / updated version of the script I built, this one works a lot better than previous iterations and avoids messy emtpy nested folder issues etc., and added logging to this version!
# I need to mention here that this ENTIRE THING only works because our Home Folders are named directly after our users, so their SAMAccountName in AD matches what their personal OneDrive URL will be
# e.g., \\homefolder\dir\FirstnameL -> will be equal to -> https://company-my.sharepoint.com/personal/FirstnameL_company_com <- which is how this entire thing works
# the very first line of this script prompts you to enter this SAMAccountName value first, which kicks off the entire rest of the thing
# so if your environment has mismatched UPN issues, or you don't name your Home Folders after your users SAMAccountName attributes, or anything else, this script is entirely useless for you!

$username = Read-Host "Enter the username (e.g., FirstnameL)"

# === LOGGING SETUP ===
$logDir = "C:\tmp\ODHF_Logs" # it just spits out a log file to here, named after whatever you entered above for the user, e.g. (C:\tmp\ODHF_Logs\FirstnameL.txt)
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}
$logFile = Join-Path $logDir "$username.txt"

function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

# Define base local path
$baseLocalRoot = "\\<YOUR_DATA_SERVER>\<YOUR_HOMEFOLDERS_ROOT>" # THIS LINE NEEDS TO BE UPDATED to work in your environment, point it at the root folder containing all of your user Home Folder data
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

# === AUTH TOKEN ===
# Assumes $Auth.access_token is already available from get-graph-token.ps1
# Check by just typing out $Auth in your shell and verify it returns access_token with some value
# You get this by running the get-token.ps1 script first in your shell, which places an access token into the $Auth variable for you in that shell session / context, allowing this script to work
if (-not $Auth.access_token) {
    Write-Log "❌ Auth token not found in `$Auth.access_token. Please run your authentication script first."
    exit
}
$headers = @{ Authorization = "Bearer $($Auth.access_token)" }

# === GET DRIVE ID ===
$driveUrl = "https://graph.microsoft.com/v1.0/users/${remoteUserId}@imcu.com/drive"
try {
    Write-Log "🔍 Retrieving OneDrive drive ID..."
    $driveResponse = Invoke-RestMethod -Uri $driveUrl -Headers $headers -Method GET
    $driveId = $driveResponse.id
    Write-Log "✅ OneDrive drive ID: $driveId"
} catch {
    Write-Log "❌ Failed to retrieve OneDrive drive ID."
    Write-Log "🔎 Error: $($_.Exception.Message)"
    exit
}

# === CREATE ROOT FOLDER ===
# URL-encode the root folder name
$encodedRootFolder = [uri]::EscapeDataString($remoteFolder)
$createRootUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root/children"
$folderBody = @{
    name = $remoteFolder
    folder = @{}
    "@microsoft.graph.conflictBehavior" = "rename"
} | ConvertTo-Json -Depth 3

try {
    Write-Log "📂 Creating root folder on OneDrive: '$remoteFolder'"
    Invoke-RestMethod -Uri $createRootUrl -Headers $headers -Method POST -Body $folderBody -ContentType "application/json" | Out-Null
} catch {
    if ($_.Exception.Response.StatusCode -eq 'Conflict' -or $_.Exception.Message -match "nameAlreadyExists") {
        Write-Log "➡️ Root folder '$remoteFolder' already exists. Continuing."
    } else {
        Write-Log "⚠️ Failed to create root folder: $($_.Exception.Message)"
    }
}

# === UPLOAD FUNCTIONS ===
$LargeFileThreshold = 4 * 1024 * 1024 # 4MB

function Upload-LargeFile {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$FileItem,
        [Parameter(Mandatory = $true)][string]$FullRemotePath,
        [Parameter(Mandatory = $true)][string]$DriveId,
        [Parameter(Mandatory = $true)][hashtable]$Headers
    )

    # Attempt to use the OneDrive module's cmdlet first, as requested.
    if (Get-Command 'Add-ODItemLarge' -ErrorAction SilentlyContinue) {
        try {
            Write-Log "Attempting large file upload for '$($FileItem.Name)' using Add-ODItemLarge..."
            # Note: The -Destination path format might need adjustment depending on the module's requirements.
            $destinationPathForCmdlet = "drive:/root:/$($FullRemotePath)"
            Add-ODItemLarge -Path $FileItem.FullName -Destination $destinationPathForCmdlet -ErrorAction Stop
            
            $global:size += $FileItem.Length
            Write-Log "✅ Successfully uploaded large file '$($FileItem.Name)' using Add-ODItemLarge."
            return
        } catch {
            Write-Log "⚠️ Add-ODItemLarge failed for '$($FileItem.Name)'. Error: $($_.Exception.Message)"
            Write-Log "Falling back to custom Graph API upload session method."
        }
    }

    # Fallback: Custom Graph API upload session method
    $encodedFullRemoteFilePath = ($FullRemotePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    $sessionUrl = "https://graph.microsoft.com/v1.0/drives/$DriveId/root:/$($encodedFullRemoteFilePath):/createUploadSession"
    $sessionBody = @{ item = @{ "@microsoft.graph.conflictBehavior" = "rename" } } | ConvertTo-Json

    try {
        Write-Log "Creating upload session for '$($FileItem.Name)'..."
        $sessionResponse = Invoke-RestMethod -Uri $sessionUrl -Headers $Headers -Method POST -Body $sessionBody -ContentType "application/json"
        $uploadUrl = $sessionResponse.uploadUrl
    } catch {
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
            
            Invoke-RestMethod -Uri $uploadUrl -Method Put -Headers $uploadHeaders -Body $chunkData -ContentType "application/octet-stream" -ErrorAction Stop
            $bytesUploaded += $bytesRead
        }
        
        Write-Host "" # Newline after progress bar
        Write-Log "⬆️ Uploaded large file '$($FileItem.Name)'"
        $global:size += $FileItem.Length
    } catch {
        Write-Host "" # Newline after progress bar
        Write-Log "❌ Failed to upload chunk for '$($FileItem.Name)': $($_.Exception.Message)"
    } finally {
        if ($fileStream) { $fileStream.Close() }
    }
}

function Copy-FilesToOneDrive ($localPath, $remotePath) {
    try {
        # Use -LiteralPath to handle filenames with special characters like brackets
        $items = Get-ChildItem -LiteralPath $localPath -ErrorAction Stop
    } catch {
        Write-Log "❌ Could not access local path '$localPath'. Error: $($_.Exception.Message)"
        return
    }

    $CountFiles = ($items | Where-Object { -not $_.PSIsContainer }).Count
    $CountFolders = ($items | Where-Object { $_.PSIsContainer }).Count

    Write-Log "📁 Scanning '$localPath' (folders/files: $CountFolders/$CountFiles)"

    # Encode the parent path for this level. Each path segment is escaped individually.
    $encodedParentPath = ($remotePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'

    foreach ($item in $items) {
        if ($item.PSIsContainer) {
            $newRemotePath = "$remotePath/$($item.Name)"
            $folderUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/${encodedParentPath}:/children"
            $folderBody = @{
                name = $item.Name # Name in the body should NOT be encoded
                folder = @{}
                "@microsoft.graph.conflictBehavior" = "rename"
            } | ConvertTo-Json -Depth 3

            try {
                Invoke-RestMethod -Uri $folderUrl -Headers $headers -Method POST -Body $folderBody -ContentType "application/json" | Out-Null
            } catch {
                if ($_.Exception.Response.StatusCode -eq 'Conflict' -or $_.Exception.Message -match "nameAlreadyExists") {
                     Write-Log "➡️ Folder '$($item.Name)' already exists in '$remotePath'. Continuing."
                } else {
                     Write-Log "⚠️ Could not create folder '$newRemotePath': $($_.Exception.Message)"
                }
            }
            Copy-FilesToOneDrive -localPath $item.FullName -remotePath $newRemotePath
        } else { # It's a file
            $fullRemoteFilePath = "$remotePath/$($item.Name)"
            $encodedFullRemoteFilePath = ($fullRemoteFilePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
            
            # Check if file already exists
            $checkUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$encodedFullRemoteFilePath"
            try {
                # If this GET succeeds, the file exists.
                Invoke-RestMethod -Uri $checkUrl -Headers $headers -Method GET -ErrorAction Stop | Out-Null
                Write-Log "⏭️ Skipping '$($item.Name)' — already exists in OneDrive."
                continue
            } catch {
                # If the error is 'NotFound', that's what we want. It means we can upload.
                if ($_.Exception.Response.StatusCode -ne 'NotFound') {
                    Write-Log "⚠️ Error checking if file '$($item.Name)' exists: $($_.Exception.Message)"
                }
            }

            # Decide on upload method based on size
            if ($item.Length -gt $LargeFileThreshold) {
                Write-Log "📦 File '$($item.Name)' is large ($([math]::Round($item.Length/1MB, 2)) MB). Using large file upload process."
                Upload-LargeFile -FileItem $item -FullRemotePath $fullRemoteFilePath -DriveId $driveId -Headers $headers
            } else {
                # Use simple upload for small files
                $uploadUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$($encodedFullRemoteFilePath):/content"
                try {
                    Invoke-RestMethod -Uri $uploadUrl -Headers $headers -Method PUT -InFile $item.FullName -ContentType "application/octet-stream" | Out-Null
                    $global:size += $item.Length
                    Write-Log "⬆️ Uploaded '$($item.Name)' to '$remotePath'"
                } catch {
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
Write-Log "`n🚀 Starting upload process..."
Copy-FilesToOneDrive -localPath $localPath -remotePath $remotePath

# Summary
Write-Log "`n✅ Upload complete!"
Write-Log "📄 Files scanned: $global:AllFiles"
Write-Log "📁 Folders scanned: $global:AllFolders"
Write-Log ("📦 Bytes transferred: {0:N0}" -f $global:Size)
