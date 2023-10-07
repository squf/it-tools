$Path = Split-Path -Parent "C:\folder\*.*"
$LogDate = Get-Date -f yyyyMMddhhmm
$Csvfile = $Path + "\ad-report.csv"
Import-Module ActiveDirectory

$DNs = @(
    "OU=example,OU=company.com,DC=corp,DC=company,DC=com"

)

$AllADUsers = @()
foreach ($DN in $DNs) {
    $Users = Get-ADUser -resultpagesize 125 -SearchBase $DN -Filter * -Properties * 
    $AllADUsers += $Users
}

$AllADUsers | Sort-Object Name | Select-Object `
@{Label = "Directory Name"; Expression = { $_.cn } },
@{Label = "Display Name"; Expression = { $_.DisplayName } },
@{Label = "Description"; Expression = { $_.Description } },
@{Label = "Title"; Expression = { $_.Title } },
@{Label = "Office"; Expression = { $_.Office } },
@{Label = "NoExpire"; Expression = { $_.PasswordNeverExpires } },
@{Label = "Role"; Expression = { $_.UserAccountControl } }|

Export-Csv -Encoding UTF8 -Path $Csvfile -NoTypeInformation #-Delimiter ","
