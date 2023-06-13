Import-Module ActiveDirectory

# Replace with the path to your CSV file
$csvPath = "C:\scripts\computer_displaynames_serials.csv"

# Import the CSV file
$csv = Import-Csv $csvPath

# Loop through each row in the CSV
foreach ($row in $csv) {
    # Get the computer object from Active Directory
    $computer = Get-ADComputer -Identity $row.Hostname

    if ($computer) {
        # Update the Description attribute with the user's display name and computer's serial number
        $description = "Assigned to user: $($row.DisplayName) | Serial Number: $($row.SerialNumber)"
        Set-ADComputer -Identity $computer -Description $description
        Write-Host "Updated description for computer $($computer.Name)"
    } else {
        Write-Warning "Computer $($row.Hostname) not found in Active Directory"
    }
}
