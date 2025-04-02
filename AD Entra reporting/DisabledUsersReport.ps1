Import-Module Microsoft.Graph
Import-Module Microsoft.Graph.Identity.Governance
Import-Module Az.Accounts
Import-Module Az.KeyVault

$AppId = "app-id-here"
$CertificateThumbprint = "thumbprint-here"
$tenantId = "tenant-id-here"

Connect-MgGraph -ClientId $AppId -CertificateThumbprint $CertificateThumbprint -tenantId $tenantId -NoWelcome
Connect-AzAccount -TenantId $tenantId -CertificateThumbprint $CertificateThumbprint -ApplicationId $AppId
 
# Get the Account Status of all users
$AccountsDisabled = Get-MgUser -Filter 'accountEnabled eq false' -All
 
#Export Disableds users to CSV
$AccountsDisabled | Select-Object DisplayName, UserPrincipalName | Export-CSV "C:\temp\DisabledUsers.csv" -NoTypeInformation

# Send email
$keyVaultName = "keyvault-here"
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$smtpUsername = "smtpserviceaccount@domain.com"
$smtpPasswordSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "SMTPPassword" -AsPlainText
$smtpPassword = ConvertTo-SecureString -String $smtpPasswordSecret -AsPlainText -Force
$smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUsername, $smtpPassword

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Send-MailMessage -To "user@domain.com", "user2@domain.com", "user3@domain.com" -From "smtpserviceaccount@domain.com" -Subject "Disabled Users" -Body "Disabled Users Report" -SmtpServer $smtpServer -Port $smtpPort -usessl -Credential $smtpCredential -attachments 'c:\temp\DisabledUsers.csv'

Disconnect-MgGraph
Disconnect-AzAccount
