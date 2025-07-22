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
-----
## Security

* I haven't set this up yet, and this will require some effort with our vendor in my case to enable, but the obvious choice from a security perspective would be to set-up [Azure Front Door](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-overview)

**Overview of how Azure Front Door solves the security problem**

* **Hides the Origin:** You point your DNS to Azure Front Door. No one would ever see or access your static site URL directly.

* **Locks Down Storage:** Configure the Storage Account firewall to only accept traffic from Azure Front Door, effectively making it private to the rest of the world.

* **Applies a Web Application Firewall (WAF):** You can attach a WAF policy to Front Door to automatically block web scraping bots, vulnerability scanners, and common cyberattacks.

* **Creates Smart Access Rules:** At the Front Door level, you can create rules to allow traffic ONLY IF:

* The request comes from your company's IP address.

* OR the request contains a special, secret HTTP header that you share with your vendor (e.g., `X-Vendor-Token: SomeSecretValue`). The vendor would configure their system to add this header when fetching your static site contents. This is a very common and secure way to allow B2B API traffic.

-----

Hope this helps! 🎉
