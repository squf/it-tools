This guide outlines the process for hosting files, such as PDFs, on an Azure Storage Account using the **Static Website** feature.

---

## General Steps & Templates

This section provides generic PowerShell cmdlets. Replace placeholders like `<your-value>` with your specific names.

### 1. Connect to Azure ☁️

First, ensure you're connected to the correct Azure account and subscription.

PowerShell

```
# Check that the Az module is installed
Get-InstalledModule -Name Az -AllVersions | Select-Object Name, Version

# Connect to your Azure account
Connect-AzAccount

# Set your subscription context
$subId = "<your-subscription-id>" # This is displayed immediately after you run Connect-AzAccount FYI
$context = Get-AzSubscription -SubscriptionId $subId
Set-AzContext $context
```

### 2. Enable Static Website 🚀

Next, enable the static website feature on your desired storage account. This will automatically create the special **`$web`** container.

PowerShell

```
# Get the target storage account and its context
$rgName = "<your-resource-group>"
$accountName = "<your-storage-account>"
$storageAccount = Get-AzStorageAccount -ResourceGroupName $rgName -Name $accountName
$ctx = $storageAccount.Context

# Enable the static website feature
Enable-AzStorageStaticWebsite -Context $ctx -IndexDocument "index.html" -ErrorDocument404Path "404.html"
```

### 3. Upload Files 📄

Upload your files to the **`$web`** container using the following command.

PowerShell

```
# Upload a file to the '$web' container
Set-AzStorageBlobContent -File "<path-to-your-local-file>" `
    -Container '$web' `
    -Blob "<name-of-blob-in-azure>" `
    -Context $ctx
```

> ⭐ Important Note on ContentType!
> 
> By default, browsers might try to download your file instead of displaying it. To fix this, you must set the correct ContentType.
> 
> - For a PDF file, add this parameter:
>     
>     -Properties @{ 'ContentType' = 'application/pdf' }
>     
> - For an HTML file, use:
>     
>     -Properties @{ 'ContentType' = 'text/html; charset=utf-8' }
>     

### 4. Find Your Site Info 🔗

Use these commands to find your website's public URL or list its contents.

PowerShell

```
# Get the primary web endpoint URL
$storageAccount = Get-AzStorageAccount -ResourceGroupName "<your-resource-group>" -Name "<your-storage-account>"
Write-Output $storageAccount.PrimaryEndpoints.Web

# List all files (blobs) in the '$web' container
Get-AzStorageBlob -Container '$web' -Context $ctx
```
-----
## Specific & on-going use

* The above cmdlets are useful for a first-time static site set-up and getting a document uploaded, I highly recommend jotting down the values entered and used during the above process for future / on-going use.

* For example at my company I had to find a way to host a PDF on a publicly accessible website for us to use with another service, so I came up with the above. However, I knew that this PDF would be getting updated within the next week or so, so I saved all the variables I used above into a separate .txt file for later use. This way I will be able to quickly go through and set my `$storageAccount` and `$ctx` et al. variables to re-use the precise same Storage Accounts / Blob resources / etc. as I did before, and keep everything in one neat little blob.

* On that note, there is also this handy piece of code for listing ALL endpoint URL's in your associated blob storage:

```
# Get the primary web URL for the site
Write-Output $storageAccount.PrimaryEndpoints.Web

# List all files and their full URLs
$webEndpoint = $storageAccount.PrimaryEndpoints.Web
Get-AzStorageBlob -Container '$web' -Context $ctx | ForEach-Object {
    $fullUrl = "$webEndpoint$($_.Name)"
    Write-Output $fullUrl
}
```

* You can also, if you prefer, just up-arrow through all of your saved Powershell cmdlet history the next time you have to do this -- it's just my opinion that this is not a very reliable thing and you may end up losing or overwriting that history by the time you need it again. Worst case scenario you can always tool around with the generic cmdlets a bit until you remember what you used the first-time, or go poke around in the Azure GUI and locate the associated Storage Account and related resources.

Hope this helps! 🎉
