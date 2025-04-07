Import-Module Az.Accounts
Import-Module Az.KeyVault

$AppId = "app-id-here"
$CertificateThumbprint = "thumbprint-here"
$tenantId = "tenant-id-here"
$Organization = "domain.onmicrosoft.com"

Connect-ExchangeOnline -AppId $AppId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
Connect-AzAccount -TenantId $tenantId -CertificateThumbprint $CertificateThumbprint -ApplicationId $AppId


Get-Mailbox -ResultSize unlimited -ErrorAction SilentlyContinue | Get-MailboxStatistics -ErrorAction SilentlyContinue | Select Displayname, ItemCount, DeletedItemCount, TotalDeletedItemSize, TotalItemSize, LastLogonTime, Database | Sort-Object TotalItemSize | Export-Csv -NoTypeInformation 'c:\temp\ADMailboxSize.csv'

# Send email
$keyVaultName = "keyvault-here"
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$smtpUsername = "smtpserviceaccount@domain.com"
$smtpPasswordSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "key-secret-here" -AsPlainText
$smtpPassword = ConvertTo-SecureString -String $smtpPasswordSecret -AsPlainText -Force
$smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUsername, $smtpPassword

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Send-MailMessage -To "user1@domain.com", "user2@domain.com" -From "smtpserviceaccount@domain.com" -Subject "Mailbox Size Report" -Body "Mailbox Size Report" -SmtpServer $smtpServer -Port $smtpPort -usessl -Credential $smtpCredential -attachments 'c:\temp\ADMailboxSize.csv'

Disconnect-AzAccount
