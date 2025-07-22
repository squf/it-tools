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
