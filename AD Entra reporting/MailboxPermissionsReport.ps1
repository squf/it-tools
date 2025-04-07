Import-Module Az.Accounts
Import-Module Az.KeyVault

$AppId = "app-id-here"
$CertificateThumbprint = "thumbprint-here"
$tenantId = "tenant-id-here"
$Organization = "domain.onmicrosoft.com"

Connect-ExchangeOnline -AppId $AppId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false
Connect-AzAccount -TenantId $tenantId -CertificateThumbprint $CertificateThumbprint -ApplicationId $AppId

# List of mailboxes to exclude
$ExcludedMailboxes = @(
    "excluded-mailbox1@domain.com",
    "excluded-mailbox2@domain.com",
    "excluded-mailbox3@domain.com"
)

CLS
Write-Host "Fetching mailboxes"
[array]$Mbx = Get-Mailbox -RecipientTypeDetails UserMailbox, SharedMailbox -ResultSize Unlimited | Where-Object { $_.UserPrincipalName -notin $ExcludedMailboxes } | Select DisplayName, UserPrincipalName, RecipientTypeDetails
If ($Mbx.Count -eq 0) { Write-Error "No mailboxes found. Script exiting..." -ErrorAction Stop } 

CLS
$Report = [System.Collections.Generic.List[Object]]::new() # Create output file 
$ProgressDelta = 100/($Mbx.count); $PercentComplete = 0; $MbxNumber = 0
ForEach ($M in $Mbx) {
    $MbxNumber++
    $MbxStatus = $M.DisplayName + " ["+ $MbxNumber +"/" + $Mbx.Count + "]"
    Write-Progress -Activity "Processing mailbox" -Status $MbxStatus -PercentComplete $PercentComplete
    $PercentComplete += $ProgressDelta
    $Permissions = Get-MailboxPermission -Identity $M.UserPrincipalName | ? {$_.User -Like "*@*" -and $_.User -ne $M.UserPrincipalName }    
    If ($Null -ne $Permissions) {
       # Grab each permission and output it into the report
       ForEach ($Permission in $Permissions) {
         $ReportLine  = [PSCustomObject] @{
           Mailbox    = $M.DisplayName
           UPN        = $M.UserPrincipalName
           Permission = $Permission | Select -ExpandProperty AccessRights
           AssignedTo = $Permission.User
           MailboxType = $M.RecipientTypeDetails } 
         $Report.Add($ReportLine) }
     } 
}     
$Report | Sort -Property @{Expression = {$_.MailboxType}; Ascending= $False}, Mailbox | Export-CSV c:\temp\MailboxPermissions.csv -NoTypeInformation
Write-Host "All done." $Mbx.Count "mailboxes scanned. Report of non-standard permissions available in c:\temp\MailboxPermissions.csv"

# Send email
$keyVaultName = "key-vault-here"
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$smtpUsername = "smtpserviceaccount@domain.com"
$smtpPasswordSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "key-secret-here" -AsPlainText
$smtpPassword = ConvertTo-SecureString -String $smtpPasswordSecret -AsPlainText -Force
$smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUsername, $smtpPassword

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Send-MailMessage -To "user1@domain.com", "user2@domain.com", "user3@domain.com", "user4@domain.com" -From "smtpserviceaccount@domain.com" -Subject "Mailbox Permissions Report" -Body "Nonstandard Mailbox Permissions Report" -SmtpServer $smtpServer -Port $smtpPort -usessl -Credential $smtpCredential -attachments 'c:\temp\MailboxPermissions.csv'

Disconnect-AzAccount
