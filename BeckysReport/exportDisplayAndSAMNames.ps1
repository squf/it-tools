# Split path
$Path = Split-Path -Parent "C:\scripts\BeckysReport\*.*"

# Create variable for the date stamp in log file
$LogDate = Get-Date -f yyyyMMddhhmm

# Define CSV and log file location variables
# They have to be on the same location as the script
$Csvfile = $Path + "\exportNames.csv"

# Import Active Directory module
Import-Module ActiveDirectory

# Set distinguishedName as searchbase, you can use one OU or multiple OUs
# Or use the root domain like DC=exoip,DC=local
$DNs = @(
    "DC=mpc,DC=com"

)

# Create empty array
$AllADUsers = @()

# Loop through every DN
foreach ($DN in $DNs) {
    $Users = Get-ADUser -SearchBase $DN -Filter * -Properties * 

    # Add users to array
    $AllADUsers += $Users
}

# Create list
$AllADUsers | Sort-Object Name | Select-Object `
@{Label = "Display Name"; Expression = { $_.DisplayName } },
@{Label = "SamAccountName"; Expression = { $_.SAMAccountName } }|

# Export report to CSV file
Export-Csv -Encoding UTF8 -Path $Csvfile -NoTypeInformation #-Delimiter ";"