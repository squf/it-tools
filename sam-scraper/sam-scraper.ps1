Import-Module ActiveDirectory

$csv = Import-Csv -Path "C:\folder\display-names.csv"

$results = @()
foreach ($row in $csv) {
    $displayName = $row.DisplayName
    $user = Get-ADUser -Filter {DisplayName -eq $displayName} -Properties sAMAccountName
    if ($user) {
        $samAccountName = $user.sAMAccountName
        $results += [pscustomobject]@{
            DisplayName = $displayName
            sAMAccountName = $samAccountName
        }
    } else {
        Write-Host "User with display name $displayName not found"
    }
}

$results | Export-Csv -Path "C:\folder\sam-scrape.csv" -NoTypeInformation
