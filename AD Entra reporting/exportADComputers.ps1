Get-ADComputer -Filter * -Properties * | Select-Object Name,DistinguishedName,OperatingSystem,Enabled | Export-Csv -Path "C:\reports\AD_Computers.csv" -NoTypeInformation
