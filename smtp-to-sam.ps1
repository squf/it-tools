$emailList = Import-Csv -Path "C:\folder\EXAMPLE.csv" -Header "Email"

$results = @()

foreach ($email in $emailList) {
    $adUser = Get-ADUser -Filter {EmailAddress -eq $email.Email} -Properties SamAccountName
    
    if ($adUser) {
        $results += [PSCustomObject]@{
            SamAccountName = $adUser.SamAccountName
        }
    }
}

$results | Export-Csv -Path "C:\folder\EXAMPLE_filtered.csv" -NoTypeInformation
