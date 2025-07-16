# This is the final / updated version of the script I built, this one works a lot better than previous iterations and avoids messy emtpy nested folder issues etc., and added logging to this version!
# Prompt for username
# I need to mention here that this ENTIRE THING only works because our Home Folders are named directly after our users, so their SAMAccountName in AD matches what their personal OneDrive URL will be
# e.g., \\homefolder\dir\FirstnameL -> will be equal to -> https://company-my.sharepoint.com/personal/FirstnameL_company_com <- which is how this entire thing works
# the very first line of this script prompts you to enter this SAMAccountName value first, which kicks off the entire rest of the thing
# so if your environment has mismatched UPN issues, or you don't name your Home Folders after your users SAMAccountName attributes, or anything else, this script is entirely useless for you! Enjoy
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
$baseLocalRoot = "\\<YOUR_DATA_SERVER>\<YOUR_HOMEFOLDERS_ROOT>"
$localPath = Join-Path $baseLocalRoot $username

# Validate local folder exists
if (-not (Test-Path $localPath)) {
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
$createRootUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/${remoteFolder}:/children"
$folderBody = @{
    name = $remoteFolder
    folder = @{}
    "@microsoft.graph.conflictBehavior" = "rename"
} | ConvertTo-Json -Depth 3

try {
    Write-Log "📂 Creating root folder on OneDrive: '$remoteFolder'"
    Invoke-RestMethod -Uri $createRootUrl -Headers $headers -Method POST -Body $folderBody -ContentType "application/json" | Out-Null
} catch {
    Write-Log "⚠️ Folder may already exist or failed to create: $($_.Exception.Message)"
}

# === UPLOAD FUNCTION ===
function Copy-FilesToOneDrive ($localPath, $remotePath) {
    $items = Get-ChildItem -Path $localPath
    $CountFiles = ($items | Where-Object { -not $_.PSIsContainer }).Count
    $CountFolders = ($items | Where-Object { $_.PSIsContainer }).Count

    Write-Log "📁 Uploading from '$localPath' (folders/files: $CountFolders/$CountFiles)"

    $global:AllFiles += $CountFiles
    $global:AllFolders += $CountFolders

    foreach ($item in $items) {
        $escapedRemotePath = [uri]::EscapeDataString($remotePath)
        $escapedFileName = [uri]::EscapeDataString($item.Name)

        if ($item.PSIsContainer) {
            $newRemotePath = "$remotePath/$($item.Name)"
            $escapedNewPath = [uri]::EscapeDataString($newRemotePath)

            $folderUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/${escapedRemotePath}:/children"
            $folderBody = @{
                name = $item.Name
                folder = @{}
                "@microsoft.graph.conflictBehavior" = "rename"
            } | ConvertTo-Json -Depth 3

            try {
                Invoke-RestMethod -Uri $folderUrl -Headers $headers -Method POST -Body $folderBody -ContentType "application/json" | Out-Null
            } catch {
                Write-Log "⚠️ Could not create folder '$newRemotePath': $($_.Exception.Message)"
            }

            Copy-FilesToOneDrive -localPath $item.FullName -remotePath $newRemotePath
        } else {
            # Check if file already exists
            $checkUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$escapedRemotePath/$escapedFileName"
            try {
                $checkResponse = Invoke-RestMethod -Uri $checkUrl -Headers $headers -Method GET -ErrorAction SilentlyContinue
                if ($checkResponse.name) {
                    Write-Log "⏭️ Skipping '$($item.Name)' — already exists in OneDrive."
                    continue
                }
            } catch {}

            $uploadUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$escapedRemotePath/${escapedFileName}:/content"
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

# Initialize counters
$global:size = 0
$global:AllFiles = 0
$global:AllFolders = 0

# Start upload
Copy-FilesToOneDrive -localPath $localPath -remotePath $remotePath

# Summary
Write-Log "`n✅ Upload complete!"
Write-Log "📄 Files uploaded: $global:AllFiles"
Write-Log "📁 Folders created: $global:AllFolders"
Write-Log ("📦 Bytes transferred: {0:N0}" -f $global:Size)
