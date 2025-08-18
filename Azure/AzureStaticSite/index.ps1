<# --- ⚙️ index.ps1 - CONFIGURATION section - ---
- I use this file for on-going maintenance to update files hosted on the Azure static site I set-up
- Basically, following the steps from the README.md file in this repo, I add a new file to the blob storage / web container on Azure in my resource group
- once that is done, this script automatically rebuilds the index.html of the website for me and republishes it
- so after running this, I can just refresh the page on my static site and immediately see the updated file list
- you will need to adjust the variables in this configuration section to match a different tenant environment, as well as the html below to match your company branding, etc.
#>
$rgName                 = "RGX"
$accountName            = "company"
$localDirectory         = "C:\your\path\here" # Use a base directory for convenience
$localPathForIndexFile  = "$localDirectory\index.html"
$logoLocalPath          = "$localDirectory\company-logo.png"
$logoBlobName           = "company-logo.png"
$faviconLocalPath       = "$localDirectory\favicon.ico"
$faviconBlobName        = "favicon.ico"

# --- 🚀 SCRIPT LOGIC ---

# 1. Get storage account context
Write-Host "Connecting to storage account '$accountName'..."
$storageAccount = Get-AzStorageAccount -ResourceGroupName $rgName -Name $accountName
$ctx = $storageAccount.Context

# 2. Upload the company logo to the '$web' container
Write-Host "Uploading company logo..."
Set-AzStorageBlobContent -File $logoLocalPath `
    -Container '$web' `
    -Blob $logoBlobName `
    -Context $ctx `
    -Properties @{ 'ContentType' = 'image/png' } `
    -Force

# 3. Upload the favicon to the '$web' container
Write-Host "Uploading favicon..."
Set-AzStorageBlobContent -File $faviconLocalPath `
    -Container '$web' `
    -Blob $faviconBlobName `
    -Context $ctx `
    -Properties @{ 'ContentType' = 'image/x-icon' } `
    -Force

# 4. Get the list of all blobs (files)
Write-Host "Fetching list of files to generate links..."
$blobs = Get-AzStorageBlob -Container '$web' -Context $ctx

# 5. Build the HTML for the list of links
$htmlLinks = $blobs | ForEach-Object {
    # Exclude the page assets (index, logo, favicon) from the list
    if ($_.Name -ne "index.html" -and $_.Name -ne $logoBlobName -and $_.Name -ne $faviconBlobName) {
        "    <li><a href='$($_.Name)'>$($_.Name)</a></li>"
    }
}

# 6. Create the full HTML page content with all new changes
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Company Hosted Documents</title>
    <link rel="icon" href="/favicon.ico" type="image/x-icon">
    <style>
        body { font-family: sans-serif; padding: 2em; background-color: #f0f0f0; } 
        ul { list-style-type: none; padding: 0; } 
        li { margin: 0.5em 0; }
        img { max-width: 300px; display: block; margin-bottom: 2em; }
        footer { text-align: center; margin-top: 3em; color: #555; font-size: 0.9em; }
        hr { margin-top: 2em; }
    </style>
</head>
<body>
    <img src="$logoBlobName" alt="Company Logo">
    <p>Last updated: $(Get-Date)</p>
    <ul>
$($htmlLinks -join "`r`n")
    </ul>
    <hr>
    <footer>
        contact: <a href="mailto:department@company.com">department@company.com</a>
    </footer>
</body>
</html>
"@

# 7. Save the HTML content to a local file
Write-Host "Saving generated content to $localPathForIndexFile..."
$htmlContent | Out-File -FilePath $localPathForIndexFile -Encoding UTF8

# 8. Upload the newly created index.html to Azure
Write-Host "Uploading updated index.html to Azure..."
Set-AzStorageBlobContent -File $localPathForIndexFile `
    -Container '$web' `
    -Blob "index.html" `
    -Context $ctx `
    -Properties @{ 'ContentType' = 'text/html; charset=utf-8' } `
    -Force

Write-Host "✅ Done! All site assets and the index file are updated."
