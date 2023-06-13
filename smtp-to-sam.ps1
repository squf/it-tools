# Import the CSV file containing the email addresses
$emailList = Import-Csv -Path "C:\scripts\DistroListMembership\Users-To-Add.csv" -Header "Email"

# Create an empty array to store the results
$results = @()

# Loop through each email address and look up the associated SamAccountName
foreach ($email in $emailList) {
    # Search Active Directory for the email address
    $adUser = Get-ADUser -Filter {EmailAddress -eq $email.Email} -Properties SamAccountName
    
    # If a user is found, add the email address and SamAccountName to the results array
    if ($adUser) {
        $results += [PSCustomObject]@{
            SamAccountName = $adUser.SamAccountName
        }
    }
}

# Export the results to a CSV file
$results | Export-Csv -Path "C:\scripts\DistroListMembership\SMTP-TO-SAM_CLEANED.csv" -NoTypeInformation
