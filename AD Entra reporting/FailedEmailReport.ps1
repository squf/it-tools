Import-Module Az.Accounts
Import-Module Az.KeyVault

$AppId = "app-id-here"
$CertificateThumbprint = "thumbprint-here"
$tenantId = "tenant-id-here"
$Organization = "domain.onmicrosoft.com"

Connect-ExchangeOnline -AppId $AppId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
Connect-AzAccount -TenantId $tenantId -CertificateThumbprint $CertificateThumbprint -ApplicationId $AppId

# Get failed emails for the past 24 hours
$StartDate = (Get-Date).AddMinutes(-15)
$FailedEmails = Get-MessageTrace -StartDate $StartDate -EndDate (Get-Date) -Status Failed
# Export failed emails to CSV
$FailedEmails | Export-Csv -Path "C:\Temp\FailedEmails.csv" -NoTypeInformation
# Display message indicating the export is completed
Write-Host "Failed emails exported to FailedEmails.csv"

# Send email
$keyVaultName = "vault-here"
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$smtpUsername = "smtpserviceaccount@domain.com"
$smtpPasswordSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "azkeyvault-secret-here" -AsPlainText
$smtpPassword = ConvertTo-SecureString -String $smtpPasswordSecret -AsPlainText -Force
$smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUsername, $smtpPassword

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Send-MailMessage -To "user@domain.com", "user2@domain.com", "user3@domain.com" -From "smtpserviceaccount@domain.com" -Subject "Failed Email Report" -Body "To further investigate failed email events, navigate to the Exchange Admin Center (admin.exchange.microsoft.com), select Mail Flow, then Message Trace. Copy the Message ID value from the report, and paste in the corresponding field. Click Search, and the result(s) will be listed. Select the message, then Message Events and/or More Information. " -SmtpServer $smtpServer -Port $smtpPort -usessl -Credential $smtpCredential -attachments 'c:\temp\FailedEmails.csv'

Disconnect-AzAccount
