# checks if c:\reports exists, creates it if it does not
$directory = "C:\reports"
if (-Not (Test-Path $directory)) {
    New-Item -Path $directory -ItemType Directory
}

# gets the AD computer info and spits it out to the .csv in c:\reports
Get-ADComputer -Filter * -Properties * | Select-Object Name,DistinguishedName,OperatingSystem,Enabled | Export-Csv -Path "$directory\AD_Computers.csv" -NoTypeInformation
