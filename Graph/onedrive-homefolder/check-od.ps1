# This one is a helper script meant to be used after you finish migrating a users Home Folder to their OneDrive
# This will specifically check a given username's OneDrive for a folder called "Home Folder" and report back its contents
# Just so you can quickly & easily verify the copy job ran correctly, if you don't believe the log file :(

# Prompt for the username
$remoteUserId = Read-Host "Enter the username (e.g., DanielQ)"

# Set up authentication headers (assuming $Auth.access_token is already available)
# Run the get-token.ps1 file first, verify you're getting an access_token returned from $Auth etc.
$headers = @{
    Authorization = "Bearer $($Auth.access_token)"
    "Content-Type" = "application/json"
}

# === GET DRIVE ID ===
$driveUrl = "https://graph.microsoft.com/v1.0/users/$remoteUserId@imcu.com/drive"
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

# === GET CONTENTS OF 'Home Folder' ===
$folderPath = "Home Folder"
$itemsUrl = "https://graph.microsoft.com/v1.0/users/$remoteUserId@imcu.com/drive/root:/${folderPath}:/children"

try {
    Write-Host "📂 Fetching contents of '$folderPath'..."
    $itemsResponse = Invoke-RestMethod -Uri $itemsUrl -Headers $headers -Method GET
    foreach ($item in $itemsResponse.value) {
        Write-Host "📄 $($item.name) - $($item.webUrl)"
    }
} catch {
    Write-Host "❌ Failed to retrieve folder contents."
    Write-Host "🔎 Error: $($_.Exception.Message)"
}
