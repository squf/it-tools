Import-Module ActiveDirectory

$csvPath = "C:\scripts\computer_displaynames_serials.csv"
$csv = Import-Csv $csvPath
foreach ($row in $csv) {
    $computer = Get-ADComputer -Identity $row.Hostname

    if ($computer) {
        $description = "Assigned to user: $($row.DisplayName) | Serial Number: $($row.SerialNumber)"
        Set-ADComputer -Identity $computer -Description $description
        Write-Host "Updated description for computer $($computer.Name)"
    } else {
        Write-Warning "Computer $($row.Hostname) not found in Active Directory"
    }
}
