# I probably still need to fix a few things here, I am making this github repo while still testing this script.
# So far it appears to be connecting to OneDrive and creating the folders correctly and moving some files over, I don't think its moving files over if they are in subfolders at this time though
# Just buy ShareGate please I'm begging you
$username = Read-Host "Enter the username (e.g., FirstnameL)"

$baseLocalRoot = "\\<YOUR_DATA_SERVER_IP>\<HOME_FOLDERS_ROOT_DIR>"
$localPath = Join-Path $baseLocalRoot $username

if (-not (Test-Path $localPath)) {
    Write-Host "❌ Local folder not found: $localPath"
    exit
}

$remoteUserId = $username.ToLower() -replace '[^a-z0-9]', ''
$remoteFolder = "Home Folder"
$remotePath = "$remoteFolder"

# oh yeah another thing i forgot to mention lol, this whole piece here assumes your user's home folders are just named after their SAMAccountNames in AD, which is pretty standard practice
# but if your company named everyones Home Folders something else or if you're having UPN problems, none of this is gonna work for you
# in my case I can just accept the username prompt at first and construct both the Home Folder path and the eventual OneDrive URL path later on since they are the same value (!)
# e.g., \\server\homefolder\FirstnameL -> https://company-my.sharepoint.com/personal/FirstnameL_company_com <- these are the same username / SAMAccountName values, so its ezpz for me (!)
Write-Host "`n🧾 Summary:"
Write-Host "📁 Local path: $localPath"
Write-Host "📂 OneDrive target folder: $remotePath"
$confirm = Read-Host "`nProceed with upload? (Y/N)"
if ($confirm -ne "Y") {
    Write-Host "❌ Operation cancelled."
    exit
}

# === AUTH TOKEN ===
# Assumes $Auth.access_token is already available from get-token.ps1 (!!!)
$headers = @{ Authorization = "Bearer $($Auth.access_token)" }

$driveUrl = "https://graph.microsoft.com/v1.0/users/${remoteUserId}@imcu.com/drive"
try {
    Write-Host "🔍 Retrieving OneDrive drive ID..."
    $driveResponse = Invoke-RestMethod -Uri $driveUrl -Headers $headers -Method GET
    $driveId = $driveResponse.id
    Write-Host "✅ OneDrive drive ID: $driveId"
} catch {
    Write-Host "❌ Failed to retrieve OneDrive drive ID."
    Write-Host "🔎 Error: $($_.Exception.Message)"
    exit
}

$createRootUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/{$remoteFolder}:/children"
$folderBody = @{
    name = $remoteFolder
    folder = @{}
    "@microsoft.graph.conflictBehavior" = "rename"
} | ConvertTo-Json -Depth 3

try {
    Write-Host "📂 Creating root folder on OneDrive: '$remoteFolder'"
    Invoke-RestMethod -Uri $createRootUrl -Headers $headers -Method POST -Body $folderBody -ContentType "application/json" | Out-Null
} catch {
    Write-Host "⚠️ Folder may already exist or failed to create: $($_.Exception.Message)"
}

function Copy-FilesToOneDrive ($localPath, $remotePath) {
    $items = Get-ChildItem -Path $localPath
    $CountFiles = ($items | Where-Object { -not $_.PSIsContainer }).Count
    $CountFolders = ($items | Where-Object { $_.PSIsContainer }).Count

    Write-Host "📁 Uploading from '$localPath' (folders/files: $CountFolders/$CountFiles)"

    $global:AllFiles += $CountFiles
    $global:AllFolders += $CountFolders

    foreach ($item in $items) {
        $escapedRemotePath = [uri]::EscapeDataString($remotePath)

        if ($item.PSIsContainer) {
            $newRemotePath = "$remotePath/$($item.Name)"
            $escapedNewPath = [uri]::EscapeDataString($newRemotePath)

            $folderUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$escapedRemotePath/$($item.Name):/children"
            $folderBody = @{
                name = $item.Name
                folder = @{}
                "@microsoft.graph.conflictBehavior" = "rename"
            } | ConvertTo-Json -Depth 3

            try {
                Invoke-RestMethod -Uri $folderUrl -Headers $headers -Method POST -Body $folderBody -ContentType "application/json" | Out-Null
            } catch {
                Write-Host "⚠️ Could not create folder '$newRemotePath': $($_.Exception.Message)"
            }

            Copy-FilesToOneDrive -localPath $item.FullName -remotePath $newRemotePath
        } else {
            $uploadUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root:/$escapedRemotePath/$($item.Name):/content"
            try {
                Invoke-RestMethod -Uri $uploadUrl -Headers $headers -Method PUT -InFile $item.FullName -ContentType "application/octet-stream" | Out-Null
                $global:size += $item.Length
            } catch {
                Write-Host "❌ Failed to upload '$($item.Name)': $($_.Exception.Message)"
            }
        }
    }
}

$global:size = 0
$global:AllFiles = 0
$global:AllFolders = 0

Copy-FilesToOneDrive -localPath $localPath -remotePath $remotePath

Write-Host "`n✅ Upload complete!"
Write-Host "📄 Files uploaded: $global:AllFiles"
Write-Host "📁 Folders created: $global:AllFolders"
Write-Host ("📦 Bytes transferred: {0:N0}" -f $global:Size)
