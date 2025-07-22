# === Setup & enable static web hosting ===

* Check Az module is installed

`Get-InstalledModule -Name Az -AllVersions | select Name,Version`

* Connect to Azure

`Connect-AzAccount`

* Set subscription context

`$context = Get-AzSubscription -SubscriptionId <subscription-id>`
`Set-AzContext $context`

* Get storage account

`$storageAccount = Get-AzStorageAccount -ResourceGroupName "<resource-group-name>" -AccountName "<storage-account-name>"`
`$ctx = $storageAccount.Context`

* Enable static web hosting

`Enable-AzStorageStaticWebsite -Context $ctx -IndexDocument <index-document-name> -ErrorDocument404Path <error-document-name>`

# === Upload files ===

* Upload objects to the $web container

```
# upload a file
set-AzStorageblobcontent -File "<path-to-file>" -Container `$web -Blob "<blob-name>" -Context $ctx
```
>If the browser prompts users users to download the file instead of rendering the contents, you can append -Properties @{ ContentType = "text/html; charset=utf-8";} to the command.

>In my case I was looking to host a PDF so I used ContentType = "application/pdf" instead

# === Find website URL ===

* Find the public URL of the static site

```
$storageAccount = Get-AzStorageAccount -ResourceGroupName "<resource-group-name>" -Name "<storage-account-name>"
Write-Output $storageAccount.PrimaryEndpoints.Web
```
