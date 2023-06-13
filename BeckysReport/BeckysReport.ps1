# Split path
$Path = Split-Path -Parent "C:\scripts\BeckysReport\*.*"

# Create variable for the date stamp in log file
$LogDate = Get-Date -f yyyyMMddhhmm

# Define CSV and log file location variables
# They have to be on the same location as the script
$Csvfile = $Path + "\BeckysReport.csv"

# Import Active Directory module
Import-Module ActiveDirectory

# Set distinguishedName as searchbase, you can use one OU or multiple OUs
# Or use the root domain like DC=exoip,DC=local
$DNs = @(
    "OU=Millerpipeline,OU=artera.com,DC=corp,DC=artera,DC=com"

)

# Create empty array
$AllADUsers = @()

# Loop through every DN
foreach ($DN in $DNs) {
    $Users = Get-ADUser -resultpagesize 125 -SearchBase $DN -Filter * -Properties * 

    # Add users to array
    $AllADUsers += $Users
}

# Create list
$AllADUsers | Sort-Object Name | Select-Object `
@{Label = "Directory Name"; Expression = { $_.cn } },
@{Label = "Display Name"; Expression = { $_.DisplayName } },
@{Label = "Description"; Expression = { $_.Description } },
@{Label = "Title"; Expression = { $_.Title } },
@{Label = "Office"; Expression = { $_.Office } },
@{Label = "NoExpire"; Expression = { $_.PasswordNeverExpires } },
@{Label = "Role"; Expression = { $_.UserAccountControl } }|

# Export report to CSV file
Export-Csv -Encoding UTF8 -Path $Csvfile -NoTypeInformation #-Delimiter ";"