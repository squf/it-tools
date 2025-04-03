Import-Module Microsoft.Graph
Import-Module Microsoft.Graph.Identity.Governance
Import-Module Az.Accounts
Import-Module Az.KeyVault

$AppId = "app-id-here"
$CertificateThumbprint = "thumbprint-here"
$tenantId = "tenant-id-here"

Connect-MgGraph -ClientId $AppId -CertificateThumbprint $CertificateThumbprint -tenantId $tenantId -NoWelcome
Connect-AzAccount -TenantId $tenantId -CertificateThumbprint $CertificateThumbprint -ApplicationId $AppId

# This script only works in my current company environment because of the following groupObjectID
# Basically this script is just checking that the user is a member of the specified group GUID + whether their account is enabled or not
# In our environment, there is a group that all users with "internet mail enabled" go into, i.e., people allowed to use OWA, which is what this report is for
$GroupObjectID = "group-guid-here"
$ReportPath = "C:\temp\InternetMailEnabled.csv"

# Get group members and their details, then export to CSV
Get-MgGroupMember -GroupId $GroupObjectID -All | ForEach-Object {
    $user = Get-MgUser -UserId $_.Id -Property DisplayName, UserPrincipalName, AccountEnabled, Id
    [PSCustomObject]@{
        DisplayName = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        AccountEnabled = $user.AccountEnabled
        ObjectId = $user.Id
    }
} | Export-Csv -LiteralPath $ReportPath -NoTypeInformation

# Send email
$keyVaultName = "keyvault-here"
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$smtpUsername = "smtpservicingaccount@domain.com"
$smtpPasswordSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "key-secret-here" -AsPlainText
$smtpPassword = ConvertTo-SecureString -String $smtpPasswordSecret -AsPlainText -Force
$smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUsername, $smtpPassword

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Send-MailMessage -To "user@domain.com" -From "smtpservicingaccount@domain.com" -Subject "Internet Mail Enabled" -Body "Internet Mail Enabled Report" -SmtpServer $smtpServer -Port $smtpPort -usessl -Credential $smtpCredential -attachments 'c:\temp\InternetMailEnabled.csv'

Disconnect-MgGraph
Disconnect-AzAccount
