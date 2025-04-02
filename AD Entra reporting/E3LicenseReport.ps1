Import-Module Microsoft.Graph
Import-Module Microsoft.Graph.Identity.Governance
Import-Module Az.Accounts
Import-Module Az.KeyVault

$AppId = "app-id-here"
$CertificateThumbprint = "thumbprint-here"
$Organization = "domain.onmicrosoft.com"
$tenantId = "tenant-id-here"

Connect-AzAccount -TenantId $tenantId -CertificateThumbprint $CertificateThumbprint -ApplicationId $AppId

$targetDate = (Get-Date).AddDays(-90).ToString("yyyy-MM-ddTHH:mm:ssZ")
$targetLicense = "05e9a617-0261-4cee-bb44-138d3ef5d965"
$keyVaultName = "vault-here"
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$smtpUsername = "smtpserviceaccount@domain.com"
$smtpPasswordSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "azkeyvault-secret-here" -AsPlainText
$smtpPassword = ConvertTo-SecureString -String $smtpPasswordSecret -AsPlainText -Force
$smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUsername, $smtpPassword

# Connect to ExchangeOnline
Connect-ExchangeOnline -AppId $AppId -CertificateThumbprint $CertificateThumbprint -Organization $Organization -ShowBanner:$false

# Connect to Graph with required permissions
Connect-MgGraph -ClientId $AppId -CertificateThumbprint $CertificateThumbprint -TenantId $tenantId -NoWelcome

$Result = @() #Result array

# Get all subscribed license SKUs to Microsoft services
$AllSkus = Get-MgSubscribedSku -All

# Get all Entra Users with the required properties
$AllUsers = Get-MgUser -All -Property "id,displayName,userPrincipalName,assignedLicenses" |
    Select-Object DisplayName, UserPrincipalName, AssignedLicenses, Id

# Iterate users one by one and resolve the license details
foreach ($User in $AllUsers) {
    $AssignedLicenses = @()

    if ($User.AssignedLicenses.Count -ne 0) {
        # Resolve license SKU details
        foreach ($License in $User.AssignedLicenses) {
            $SkuInfo = $AllSkus | Where-Object { $_.SkuId -eq $License.SkuId }
            $AssignedLicenses += $SkuInfo.SkuPartNumber
        }
    }

    # Filter users with SPE_E3 license
    if ($AssignedLicenses -contains "SPE_E3") {
        # Add user detail to $Result array one by one
        $Result += New-Object PSObject -Property $([ordered]@{
            UserName = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            UserId = $User.Id
            IsLicensed = if ($User.AssignedLicenses.Count -ne 0) { $true } else { $false }
            Licenses = $AssignedLicenses -join ","
        })
    }
}

# Sort the result by UserName
$SortedResult = $Result | Sort-Object UserName

# Export All Microsoft 365 Users report to CSV
$SortedResult | Export-Csv "C:\Temp\E3LicenseReport.CSV" -NoTypeInformation -Encoding UTF8

# Save to CSV
$csvPath = "C:\temp\E3LicenseReport.csv"
$SortedResult | Export-Csv -Path $csvPath -NoTypeInformation

# Send email with CSV attachment
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Send-MailMessage -To "user@domain.com", "user2@domain.com", "user3@domain.com" -From $smtpUsername -Subject "E3 License Report" -Body "Please find attached the E3 License Report" -SmtpServer $smtpServer -Port $smtpPort -UseSsl -Credential $smtpCredential -Attachments $csvPath

Disconnect-Graph
Disconnect-AzAccount
